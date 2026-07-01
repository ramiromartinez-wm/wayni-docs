# Consultar cuotas según línea de crédito y monto solicitado

> Este documento es válido para el flujo originante por la billetera, no por la web de préstamos.

## Diagrama de secuencia
![Diagrama](seq.png)

## Ejemplos

### Invalid credit product

**Request:** `GET /credits/v1/wallet/personal-loans/options/10000`

**Response**

```json
{
    "code": "invalid_credit_product",
    "message": "loan.error.invalid_credit_product",
    "errors": null,
    "sourceFile": "/var/www/waynimovil-api/app/Domain/Loans/LoanValidator.php",
    "line": "37"
}
```

### Invalid minimum amount

**Request:** `GET /credits/v1/wallet/cash-advances/options/200`

**Response**

```json
{
    "code": "loan_option_invalid",
    "message": "La opción solicitada no existe o es inválida.",
    "errors": null,
    "sourceFile": "/var/www/waynimovil-api/app/Domain/Loans/LoanOptionValidator.php",
    "line": "281"
}
```

### Invalid delivery amount

**Request:** `GET /credits/v1/wallet/cash-advances/options/3120`

**Response**

```json
{
    "code": "loan_option_invalid",
    "message": "La opción solicitada no existe o es inválida.",
    "errors": null,
    "sourceFile": "/var/www/waynimovil-api/app/Domain/Loans/LoanOptionValidator.php",
    "line": "281"
}
```

## Invariantes

- Para el tipo de producto billetera (`wallet`) solo se admiten los tipos de crédito (`loan_type`): adelantos (`cash-advances`) y adelantos tasa 0 (`free-interest-advances`). Cualquier otra combinación arroja un error de tipo `invalid_credit_product`.
- Todos los tipos de crédito (`loan_type`), tienen un monto mínimo establecido. En caso de que la solicitud de un cliente no supere dicho mínimo; un error de tipo `loan_option_invalid` es lanzado.
- El monto solicitado debe coincidir con el campo `delivery_amount` de alguna estructura crediticia activa. En caso de que la solicitud de un cliente coincida; un error de tipo `loan_option_invalid` es lanzado.
- El cliente debe tener un scoring crediticio > 0 y vigente. Caso contrario, retorna los siguientes mensajes de validación respectivamente: `bad_credit_score` y `nonexistent_expired_credit_line`, respectivamente.
- El monto solicitado debe ser mayor a la capacidad remanente paara `loan_type`. Caso contrario, retorna un error de tipo `credit_line_quota_exceeded`.

## Detalles de implementación

- La validación entre tipo de producto (`product`) y tipo de préstamo (`loan_type`), se lleva a cabo a traves de mappings definidos en `We\Domain\Constants\LoansContstants`.
- Los montos mínimos, que un cliente puede solicitar por tipo de préstamo (`loan_type`), están definidos en una tabla de configuración global (`environment_system`) y llevan el sufijo `-principal-minimum-amount`.
    ```sql
    SELECT * FROM environment_system es WHERE slug LIKE "%-principal-minimum-amount";
    ```
    | Config | Aplicable a |
    |--------|-------------|
    | `personal-loan-principal-minimum-amount` | `personal-loans` |
    | `advance-principal-minimum-amount` | `cash-advances` `interest-free-advances` |
    | `refinanced-loan-principal-minimum-amount` | `refinanced-loans` |
- El acceso a las variables de configuración globales es abstraido por la clase `We\Services\Credits\CreditConfigurationService`.
- Las validaciones de los pasos (4) y (5) son llevadas a cabo por la clase `We\Domain\Loans\LoanOptionValidator::performExistenceByAmountValidation`.
- Para obtener una estructura crediticia (opción de crédito) a partir del monto solicitado, se realiza la siguiente consulta.
    ```sql
    SELECT * FROM credit_structure cs WHERE cs.active  = 1 AND cs.country_id = 32 AND cs.currency_id = 3 AND cs.amount_delivery = ?;
    ```
- Los pasos (7), (8) y (9) se encuentran implementados en `We\Domain\Wallets\Advances\WalletAdvancesValidator::performCreditLineQuotaValidation`.

## Dudas

## Problemas (?)

- El mensaje error para la validación del caso (4) y (5) es el mismo. No permite al usuario discriminar una acción para recuperarse.

## Casos de uso relacionados

- GetCreditBalance: Obtiene la capacidad crediticia del cliente. Documentado en [este artículo](../000-credit-capacity/README.md).