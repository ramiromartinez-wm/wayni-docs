# Historia de Usuario: Balance de línea de crédito compatible con consulta de cuotas — producto `loan` / tipo `personal-loan`

## Narrativa

> **Como** cliente con una línea de crédito activa de tipo `personal-loan` dentro del producto `loan`,
> **quiero** que al consultar las cuotas/opciones disponibles para un monto desde la aplicación mobile el sistema calcule mi cupo disponible real,
> **para** poder ver y seleccionar montos de préstamo válidos según mi línea de crédito, en lugar de que la solicitud sea rechazada por un cupo disponible que el sistema reporta erróneamente en 0.

*(Historia complementaria, de cara al equipo de plataforma)*

> **Como** desarrollador responsable del dominio de líneas de crédito,
> **quiero** que `CreditLineSummaryBuilder`/`CreditLineBalanceDto`/`CreditLineSummaryDto` calculen el `remainingAmount` por tipo de préstamo también para el producto `loan`,
> **para** que la lógica de sub-balances sea consistente entre productos (`wallet` y `loan`) y no dependa de una estructura pensada únicamente para `wallet`.

---

## Contexto técnico

El endpoint consumido por la app mobile para consultar cuotas/opciones de un monto es:

```
GET credits/v1/{credit_product}/{loan_type}/options/{amount}
→ CreditOptionController@getOptionByClient
```

(`app/Http/routes.php:58`, middleware `jwt.sso_config` + `jwt.sso_auth`)

Ese controlador valida el cupo disponible antes de devolver las opciones de cuotas:

```php
$summary = $this->creditLineSummaryBuilder->build($clientId, $creditProduct);
$this->walletAdvanceValidator->performCreditLineQuotaValidation(
    $summary->getIsValid(), $summary->getCreditScore(),
    $summary->getRemainingAmountByType($loanType), // <- siempre 0.00 para personal-loan
    $amount
);
```
(`app/Http/Controllers/CreditOptionController.php:82-90`)

---

## AS-IS

1. `CreditLineSummaryBuilder::buildBalance()` (`app/Domain/Credits/Lines/CreditLineSummaryBuilder.php:71`) sólo arma **sub-balances** (`subBalances`) cuando `$creditProduct === ProductConstants::WALLET`, delegando en `WalletCreditLineBalanceStrategy`, que construye dos `CreditLineBalanceDto` hijos indexados por `loanType`: `cash-advance` e `interest-free-advance`.
2. Para `ProductConstants::LOANS` (producto `loan`, tipo `personal-loan`), se construye un `CreditLineBalanceDto` "plano" (`approvedAmount`, `allocatedAmount`, `remainingAmount`) **sin sub-balances** (`CreditLineSummaryBuilder.php:109-118`).
3. `CreditLineSummaryDto::getRemainingAmountByType($type)` (`app/Dtos/Credits/Lines/CreditLineSummaryDto.php:94-103`) siempre intenta resolver el remaining vía `$this->balance->getSubBalance($type)`. Para `personal-loan` ese sub-balance **nunca existe**, por lo que la función cae al fallback `LoanConfigurationConstants::DEFAULT_AMOUNT` (`0.0`), **descartando el remaining real ya calculado** en el balance raíz.
4. Consecuencia funcional: para cualquier cliente con línea `loan`/`personal-loan`, `getRemainingAmountByType('personal-loan')` devuelve `0.00` sin importar el cupo real disponible. En `CreditOptionController::getOptionByClient`, esto hace que `WalletAdvanceValidator::performCreditLineQuotaValidation` falle siempre con `CREDIT_LINE_QUOTA_EXCEEDED_ERROR` (`remainingAmount(0.00) < amount`), bloqueando la consulta de cuotas incluso cuando el cliente tiene cupo suficiente.
5. Evidencia en el código actual (WIP, sin limpiar): comentarios de debug en `CreditLineSummaryDto.php:96-101` (`// personal-loan -> subbalance = null`) y en `CreditLineBalanceDto.php:116` (`// todo: harcodear sub balances wallet en 0 si es loans, sino el remaining me da siempre 0.00`) confirman el diagnóstico del bug, pero la solución aún no está implementada de forma limpia (hay `var_dump/die` comentados y TODOs sin resolver).

---

## TO-BE

1. `getRemainingAmountByType('personal-loan')` (o el flujo de construcción del balance para el producto `loan`) debe devolver el **remaining real** del cliente (`approvedAmount - allocatedAmount`), ya sea:
   - construyendo un sub-balance también para `LOANS` (agregando un `CreditLineBalanceDto` hijo con `loanType = 'personal-loan'`, análogo a lo que hace `WalletCreditLineBalanceStrategy` para `wallet`), o
   - haciendo que `getRemainingAmountByType` use el `remainingAmount` del balance raíz cuando el producto no tiene sub-balances definidos, en lugar de caer directo a `DEFAULT_AMOUNT`.
2. El endpoint `GET credits/v1/loan/personal-loan/options/{amount}` debe reflejar el cupo real: un cliente con cupo suficiente debe poder consultar y obtener las opciones de cuotas exitosamente (200), y un cliente sin cupo suficiente debe seguir recibiendo `CREDIT_LINE_QUOTA_EXCEEDED_ERROR` de forma correcta (no por defecto, sino porque realmente no alcanza).
3. El comportamiento actual para `wallet` (`cash-advance` / `interest-free-advance`) no debe verse alterado — la solución debe ser retrocompatible con la estrategia existente.
4. El código de diagnóstico (var_dumps comentados, TODOs de investigación) debe quedar limpio antes de mergear a `master`.

---

## Criterios de aceptación

- [ ] Dado un cliente con línea `loan`/`personal-loan` activa y cupo disponible **mayor** al monto solicitado, al consultar `GET credits/v1/loan/personal-loan/options/{amount}` recibe `200` con las opciones de cuotas correspondientes.
- [ ] Dado un cliente con línea `loan`/`personal-loan` activa y cupo disponible **menor** al monto solicitado, la consulta falla con `CREDIT_LINE_QUOTA_EXCEEDED_ERROR` (comportamiento esperado, no por el bug del remaining en 0).
- [ ] El `remaining_amount` reportado para `personal-loan` coincide con `approved_amount - allocated_amount` de la línea vigente del cliente.
- [ ] La consulta de opciones para `wallet` (`cash-advance`, `interest-free-advance`) sigue funcionando sin regresiones.
- [ ] No quedan `var_dump`/`die` ni comentarios de debug en `CreditLineSummaryBuilder.php`, `CreditLineBalanceDto.php` ni `CreditLineSummaryDto.php`.

---

## Archivos involucrados

| Archivo | Rol en el bug/solución |
|---|---|
| `app/Domain/Credits/Lines/CreditLineSummaryBuilder.php:71` (`buildBalance`) | Sólo arma sub-balances para `WALLET`; para `LOANS` arma un balance plano sin sub-balance de `personal-loan` |
| `app/Strategies/CreditLines/Summaries/WalletCreditLineBalanceStrategy.php` | Referencia de cómo se arman sub-balances por tipo (usado hoy solo por `wallet`) |
| `app/Dtos/Credits/Lines/CreditLineBalanceDto.php:94` (`getSubBalance`) | Devuelve `null` si el tipo no fue registrado como sub-balance |
| `app/Dtos/Credits/Lines/CreditLineSummaryDto.php:94` (`getRemainingAmountByType`) | Cae a `DEFAULT_AMOUNT` (0.0) cuando no hay sub-balance — origen directo del bug |
| `app/Domain/Constants/LoanConfigurationConstants.php:41` | `DEFAULT_AMOUNT = 0.0` |
| `app/Domain/Constants/CreditConstants.php:14` | `LOAN_TYPES_BY_CREDIT_PRODUCT_MAPPING` — `loans → [personal-loan, refinanced-loan]` |
| `app/Http/Controllers/CreditOptionController.php:61` (`getOptionByClient`) | Endpoint de consulta de cuotas consumido por la app mobile; consumidor final del bug |
| `app/Domain/Wallets/Advances/WalletAdvanceValidator.php:101` | Valida el cupo (`performCreditLineQuotaValidation`) usando el remaining ya corrompido |
| `app/Http/routes.php:58` | `GET credits/v1/{credit_product}/{loan_type}/options/{amount}` |
