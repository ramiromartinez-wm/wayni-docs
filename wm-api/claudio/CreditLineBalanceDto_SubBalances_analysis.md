# Análisis: `subBalances` — `CreditLineBalanceDto`

**Archivo:** `app/Dtos/Credits/Lines/CreditLineBalanceDto.php`

---

## Descripción general

`subBalances` es una propiedad privada de `CreditLineBalanceDto` que almacena un mapa de balances desagregados por tipo de préstamo. Se inicializa como array vacío en el constructor y solo se popula a través del factory method estático `constructWithSubBalances`.

---

## 1. Constructor y `constructWithSubBalances`

`subBalances` **no se llena en el constructor** — se inicializa como `[]`. Solo se popula vía:

```php
// CreditLineBalanceDto.php:44
public static function constructWithSubBalances(
    float $approvedAmount, float $allocatedAmount, CreditLineBalanceDto ...$subBalances
): CreditLineBalanceDto
{
    $self = new self($approvedAmount, $allocatedAmount);

    foreach ($subBalances as $subBalance) {
        $self->subBalances[$subBalance->getLoanType()] = $subBalance;  // clave = loanType
    }

    return $self;
}
```

El array se indexa por el `loanType` de cada sub-balance (`cash-advance`, `interest-free-advance`).

---

## 2. Único lugar donde se construye: `WalletCreditLineBalanceStrategy`

**Archivo:** `app/Strategies/CreditLines/Summaries/WalletCreditLineBalanceStrategy.php:39`

Solo aplica al producto **WALLET**. Construye dos `CreditLineBalanceDto` hijos y los pasa como `subBalances`:

```php
return CreditLineBalanceDto::constructWithSubBalances(
    $totalApprovedAmount, $totalAllocatedAmount,
    $regularBalance,       // sub-balance de 'cash-advance'
    $interestFreeBalance   // sub-balance de 'interest-free-advance'
);
```

Esta estrategia es invocada desde `CreditLineSummaryBuilder::buildBalance` únicamente cuando `$creditProduct === ProductConstants::WALLET`.

---

## 3. Fuentes de datos de la DB

### Fuente 1 — Tabla `credit_rating_history`

`CreditLineSummaryBuilder.php:75` consulta la última línea de crédito del cliente:

```sql
SELECT * FROM credit_rating_history
WHERE client_id = {clientId}
  AND stage     = {stage_del_producto}   -- 'wallet' para WALLET
ORDER BY id DESC
LIMIT 1
```

Columnas usadas para construir los sub-balances:

| Columna | Uso |
|---|---|
| `final_amount` | Monto aprobado total para adelantos regulares |
| `interest_free_amount` | Monto aprobado para adelantos tasa 0 |
| `valid_from` / `valid_until` | Delimitadores del período de crédito activo |
| `credit_structure_id` | Id de la estructura de crédito máxima (para ICR) |
| `is_icr_limit_active` | Si aplica límite ICR sobre los montos aprobados |

### Fuente 2 — Tabla `loan`

`CreditLineSummaryBuilder.php:81` consulta los adelantos consumidos dentro del período vigente:

```sql
SELECT id, amount, loan_type_slug FROM loan
WHERE client_id        = {clientId}
  AND loan_type_slug   IN ('cash-advance', 'interest-free-advance')
  AND state            NOT IN ('cancelled')
  AND created_at       BETWEEN {valid_from} AND {valid_until}
```

Con esos loans, la estrategia calcula el monto consumido por tipo:

```php
$regularAllocatedAmount      = loans con loan_type_slug = 'cash-advance'          → sum(amount)
$interestFreeAllocatedAmount = loans con loan_type_slug = 'interest-free-advance' → sum(amount)
```

---

## 4. Cómo se construye cada sub-balance

```
regularBalance (loanType = 'cash-advance')
├── approvedAmount  = final_amount             (de credit_rating_history)
├── allocatedAmount = sum(loan.amount)         (adelantos regulares del período)
└── remainingAmount = approvedAmount - allocatedAmount

interestFreeBalance (loanType = 'interest-free-advance')
├── approvedAmount  = interest_free_amount     (de credit_rating_history)
├── allocatedAmount = sum(loan.amount)         (adelantos tasa 0 del período)
└── remainingAmount = min(
        interest_free_amount - interestFreeAllocatedAmount,
        regularBalance.remainingAmount          ← acotado por el cupo total restante
    )
```

> El `remainingAmount` de `interestFreeBalance` está acotado por el saldo total disponible
> (`calculateAvailableInterestFreeAmount` en `CreditLineUtilities.php:24`), porque el cupo
> tasa 0 comparte el mismo pool que el adelanto regular.

---

## 5. Flujo completo

```
buildBalance(clientId, 'wallet')                      [CreditLineSummaryBuilder.php:71]
│
├─ credit_rating_history → last row (client_id + stage = wallet)
│   ├── final_amount           → totalApprovedAmount
│   ├── interest_free_amount   → interestFreeApprovedAmount
│   └── valid_from / valid_until
│
├─ loan table → loans del período (no cancelados, entre valid_from y valid_until)
│   ├── cash-advance loans             → regularAllocatedAmount
│   └── interest-free-advance loans   → interestFreeAllocatedAmount
│
└─ WalletCreditLineBalanceStrategy.build()            [WalletCreditLineBalanceStrategy.php:15]
    ├── regularBalance       { approvedAmount, allocatedAmount, remainingAmount }
    ├── interestFreeBalance  { approvedAmount, allocatedAmount, remainingAmount (acotado) }
    └── CreditLineBalanceDto::constructWithSubBalances(total, totalAllocated, regular, interestFree)
         └── subBalances = {
               'cash-advance'          → regularBalance,
               'interest-free-advance' → interestFreeBalance
             }
```

---

## Archivos involucrados

| Archivo | Responsabilidad |
|---|---|
| `app/Dtos/Credits/Lines/CreditLineBalanceDto.php:44` | Factory method `constructWithSubBalances` |
| `app/Domain/Credits/Lines/CreditLineSummaryBuilder.php:71` | Orquesta la construcción del balance |
| `app/Strategies/CreditLines/Summaries/WalletCreditLineBalanceStrategy.php` | Construye los dos sub-balances y llama `constructWithSubBalances` |
| `app/Services/Credits/Lines/CreditLineUtilities.php:24` | `calculateAvailableInterestFreeAmount` — acota el cupo tasa 0 |
| `app/Domain/CreditRatings/CreditRatingHistoryRepository.php:16` | Query a `credit_rating_history` |
| `app/Domain/Credits/Lines/CreditLineCriteria.php` | Criterios de período y cancelación para query de loans |
| `app/Domain/Constants/LoanConstants.php` | Slugs de tipos (`cash-advance`, `interest-free-advance`) |
| `app/Domain/Constants/CreditConstants.php:14` | `LOAN_TYPES_BY_CREDIT_PRODUCT_MAPPING` |
