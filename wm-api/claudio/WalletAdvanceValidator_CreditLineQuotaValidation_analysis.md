# Análisis: `performCreditLineQuotaValidation` — `WalletAdvanceValidator`

**Archivo:** `app/Domain/Wallets/Advances/WalletAdvanceValidator.php:101`

---

## Descripción general

El método valida que un cliente pueda realizar un adelanto de wallet. Encadena dos validaciones sobre la línea de crédito; cualquier falla corta la ejecución y retorna un `ValidationResult` con el error correspondiente.

```php
public function performCreditLineQuotaValidation(
    bool $isValid, int $creditScore, float $remainingAmount, int $attemptAmount
): ValidationResult
{
    $validation = $this->performCreditLineCheckValidation($isValid, $creditScore);

    if ($validation->wasFailed) {
        return $validation;
    }

    return $this->performCreditLineQuotaBaseValidation($remainingAmount, $attemptAmount);
}
```

---

## Validación 1 — Estado de la línea de crédito (`performCreditLineCheckValidation`)

Se ejecuta con `$isValid` y `$creditScore`. Internamente realiza dos chequeos en secuencia:

### 1a. Vigencia de la línea (`$isValid`)

```php
// WalletAdvanceValidator.php:183
if (!$isValid) {
    $validation->setFailure(
        ErrorCodeConstants::NONEXISTENT_EXPIRED_CREDIT_LINE,
        trans('wallet.errors.cash_advance.nonexistent_expired_credit_line')
    );
}
```

- `$isValid === false` → falla con `NONEXISTENT_EXPIRED_CREDIT_LINE`
- Indica que la línea de crédito del cliente no existe o está vencida.

### 1b. Score crediticio (`checkHistoryScoreValidity`)

```php
// CreditRatingValidator.php:19
return $creditScore > CreditRatingConstants::MINIMUM_BAD_CREDIT_SCORE; // > 0
```

- Verifica que `$creditScore > 0` (`MINIMUM_BAD_CREDIT_SCORE = 0`)
- Si el score es `<= 0` → falla con `BAD_CREDIT_SCORE`
- Un score de 0 o negativo indica historial crediticio malo.

---

## Validación 2 — Cupo disponible (`performCreditLineQuotaBaseValidation`)

Solo se ejecuta si la validación anterior pasó.

```php
// WalletAdvanceValidator.php:231
if ($remainingAmount < $attemptAmount) {
    $validation->setFailure(
        ErrorCodeConstants::CREDIT_LINE_QUOTA_EXCEEDED_ERROR,
        trans('wallet.errors.cash_advance.credit_line_quota_exceeded')
    );
}
```

Compara el saldo disponible en la línea de crédito contra el monto solicitado. Si el `remainingAmount` es menor al `attemptAmount`, falla con `CREDIT_LINE_QUOTA_EXCEEDED_ERROR`.

---

## Callers y origen de los parámetros

El método recibe sus valores desde el `CreditLineSummaryBuilder`, construido previamente en el caller:

```php
// CreditOptionController.php:86
$this->walletAdvanceValidator->performCreditLineQuotaValidation(
    $summary->getIsValid(),
    $summary->getCreditScore(),
    $summary->getRemainingAmountByType($loanType),
    $amount   // monto que el cliente quiere adelantar
);
```

| Parámetro        | Tipo    | Origen                                                        |
|------------------|---------|---------------------------------------------------------------|
| `$isValid`       | `bool`  | Si la línea de crédito está activa y no expiró                |
| `$creditScore`   | `int`   | Score histórico del cliente                                   |
| `$remainingAmount` | `float` | Saldo disponible en la línea, filtrado por tipo de préstamo |
| `$attemptAmount` | `int`   | Monto solicitado en el adelanto                               |

### Callers conocidos

| Archivo | Línea | Contexto |
|---|---|---|
| `app/Http/Controllers/CreditOptionController.php` | 86 | Validación de opciones de crédito |
| `app/Http/Controllers/CreditRatingController.php` | 1221, 1291 | Validación en flujo de credit rating |

---

## Flujo completo

```
performCreditLineQuotaValidation($isValid, $creditScore, $remainingAmount, $attemptAmount)
│
├─ [1a] ¿isValid?
│        No → FALLA (NONEXISTENT_EXPIRED_CREDIT_LINE)
│
├─ [1b] ¿creditScore > 0?
│        No → FALLA (BAD_CREDIT_SCORE)
│
└─ [2]  ¿remainingAmount >= attemptAmount?
         No → FALLA (CREDIT_LINE_QUOTA_EXCEEDED_ERROR)
         Sí → OK → ValidationResult() vacío (sin falla)
```

---

## Archivos involucrados

| Archivo | Responsabilidad |
|---|---|
| `app/Domain/Wallets/Advances/WalletAdvanceValidator.php:101` | Orquesta las validaciones |
| `app/Domain/Wallets/Advances/WalletAdvanceValidator.php:179` | `performCreditLineCheckValidation` — vigencia + score |
| `app/Domain/Wallets/Advances/WalletAdvanceValidator.php:227` | `performCreditLineQuotaBaseValidation` — cupo disponible |
| `app/Domain/CreditRatings/CreditRatingValidator.php:17` | `checkHistoryScoreValidity` — score > 0 |
| `app/Domain/Constants/CreditRatingConstants.php:7` | `MINIMUM_BAD_CREDIT_SCORE = 0` |
| `app/Http/Controllers/CreditOptionController.php:86` | Caller principal |
| `app/Http/Controllers/CreditRatingController.php:1221` | Caller secundario |
