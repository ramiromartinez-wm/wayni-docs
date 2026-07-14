# Análisis: `performExistenceByAmountValidation` — `LoanOptionValidator`

**Archivo:** `app/Domain/Loans/LoanOptionValidator.php:66`

---

## Descripción general

El método verifica si existe una opción de préstamo válida y activa para un monto dado. Ejecuta dos validaciones en secuencia; cualquier falla retorna un `ValidationResult` con error `LOAN_OPTION_INVALID`.

```php
public function performExistenceByAmountValidation(string $loanType, int $amount): ValidationResult
{
    if (!$this->checkAmountMinimumValidityByType($loanType, $amount)) {
        return $this->buildInvalidValidation();
    }

    $creditStructureDb = $this->creditStructureRepository->checkExistenceAndActiveByAmount(
        $amount, QueryOperatorsConstants::EQUAL
    );

    if (empty($creditStructureDb)) {
        return $this->buildInvalidValidation();
    }

    return new ValidationResult();
}
```

---

## Validación 1 — Monto mínimo (`checkAmountMinimumValidityByType`)

### Flujo de resolución del monto mínimo

```
getTypedVariable($loanType, 'principal-minimum-amount')
  → getTypedVariableSlug($loanType, slug)     [CreditConfigurationService:219]
  → busca en CONFIGURATION_BY_SUBTYPE primero, luego CONFIGURATION_BY_TYPE
  → retorna el slug específico al tipo
  → getUnsafeBySlug(slug)                     [ConfigurationVariableService:25]
  → consulta tabla `environments` por slug
  → retorna ConfigurationVariable
  → .getNumericValue()
```

### Mapeo de slugs por tipo de préstamo

`CreditConfigurationService.php:19`

| `$loanType`             | Slug consultado en DB                                    |
|-------------------------|----------------------------------------------------------|
| `personal`              | `personal-loan-principal-minimum-amount`                 |
| `advance`               | `advance-principal-minimum-amount`                       |
| `interest-free-advance` | `advance-principal-minimum-amount`                       |
| `refinanced`            | `refinanced-loan-principal-minimum-amount`               |

> Los subtipos (`CONFIGURATION_BY_SUBTYPE`) tienen precedencia sobre los tipos base (`CONFIGURATION_BY_TYPE`).

### Comparación

```php
// LoanOptionValidator.php:59
if ($amount < $minAmount) return false;
```

Si el monto solicitado es **estrictamente menor** al mínimo configurado en DB → falla.

---

## Validación 2 — Existencia de `CreditStructure` activa (`checkExistenceAndActiveByAmount`)

### Implementación en el repositorio

`CreditStructureRepository.php:88`

```php
public function checkExistenceAndActiveByAmount(float $lendingAmount, string $operator): bool
{
    $this->pushCriteriaByAmount($lendingAmount, $operator);
    $result = $this->exists();
    $this->resetCriteria();
    return $result;
}

private function pushCriteriaByAmount(int $amount, string $operator): void
{
    $this->pushActiveLocalizedCriteria();  // active + country_id + currency_id
    $this->pushCriteria(new CriteriaByAmountDelivery($operator, $amount));
    $this->orderBy('amount_delivery', ...);
}
```

### Criterios aplicados

| Criterio              | Columna        | Valor                                        | Archivo                          |
|-----------------------|----------------|----------------------------------------------|----------------------------------|
| `CriteriaByActive`    | `active`       | `= true`                                     | `Criterials/CriteriaByActive.php`       |
| `CriteriaByCountryId` | `country_id`   | `= LocalizationHelper::getCountryNumericCode()` | `Criterials/CriteriaByCountryId.php` |
| `CriteriaByCurrencyId`| `currency_id`  | `= LocalizationHelper::getCurrencyNumericCode()` | `Criterials/CriteriaByCurrencyId.php` |
| `CriteriaByAmountDelivery` | `amount_delivery` | `= $amount` (operador `EQUAL`)      | `Criterials/CriteriaByAmountDelivery.php` |

### Query equivalente

```sql
SELECT EXISTS (
  SELECT 1 FROM credit_structure
  WHERE active        = 1
    AND country_id    = {país_actual}
    AND currency_id   = {moneda_actual}
    AND amount_delivery = {$amount}
)
```

> El operador `EQUAL` (`=`) es determinante: no busca un rango de estructuras que contengan el monto, sino una fila cuyo `amount_delivery` sea **exactamente igual** al monto solicitado.

---

## Flujo completo

```
performExistenceByAmountValidation($loanType, $amount)
│
├─ [1] Obtiene min_amount desde tabla environments
│       (slug resuelto dinámicamente según $loanType)
│       Si $amount < min_amount
│       └─ FALLA → ValidationResult(LOAN_OPTION_INVALID)
│
└─ [2] Consulta credit_structure con 4 filtros:
│       active=1  +  country_id  +  currency_id  +  amount_delivery = $amount
│       Si no existe ninguna fila
│       └─ FALLA → ValidationResult(LOAN_OPTION_INVALID)
│
└─ OK → ValidationResult() vacío (sin falla)
```

---

## Archivos involucrados

| Archivo | Responsabilidad |
|---|---|
| `app/Domain/Loans/LoanOptionValidator.php:66` | Orquesta ambas validaciones |
| `app/Services/Credits/CreditConfigurationService.php:151` | Resuelve slug por tipo y obtiene variable |
| `app/Services/Common/ConfigurationVariableService.php:25` | Consulta la variable en DB por slug |
| `app/Domain/CreditStructures/CreditStructureRepository.php:88` | Ejecuta la query de existencia |
| `app/Domain/Criterials/CriteriaByActive.php` | Filtro `active = 1` |
| `app/Domain/Criterials/CriteriaByCountryId.php` | Filtro por país |
| `app/Domain/Criterials/CriteriaByCurrencyId.php` | Filtro por moneda |
| `app/Domain/Criterials/CriteriaByAmountDelivery.php` | Filtro `amount_delivery = $amount` |
| `app/Domain/Constants/LoanConfigurationConstants.php` | Slugs de configuración |
| `app/Domain/Constants/QueryOperatorsConstants.php` | Operadores SQL (`=`, `>=`, etc.) |
