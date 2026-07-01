INSERT INTO waynimovil_db.credit_rating_history (
    id,
    contact_id,
    client_id,
    stage,
    credit_structure_id,
    credit_score,
    extra_score_points,
    adjustment_rate,
    original_amount,
    adjusted_amount,
    final_amount,
    icr_final_amount,
    interest_free_amount,
    icr_interest_free_amount,
    is_icr_limit_active,
    income_estimate,
    icr_limit,
    committed_limit,
    is_active,
    valid_from,
    valid_until,
    created_at,
    updated_at,
    deleted_at
)
VALUES (
    NULL,                               -- id
    NULL,                                -- contact_id
    47091,                               -- client_id
    'loan',                            -- stage (loan|wallet)
    872,                                 -- credit_structure_id
    0,                                   -- credit_score
    1200,                                -- extra_score_points
    0.25000000000000,                    -- adjustment_rate
    270000.00000000000000,               -- original_amount
    67000.00000000000000,                -- adjusted_amount
    62000.00000000000000,                -- final_amount
    62000.00000000000000,                -- icr_final_amount
    20000.00000000000000,                -- interest_free_amount
    20000.00000000000000,                -- icr_interest_free_amount
    1,                                   -- is_icr_limit_active
    1278953.00000000000000,              -- income_estimate
    0.30000000000000,                    -- icr_limit
    377593.00000000000000,               -- committed_limit
    1,                                -- is_active
    NOW(),               -- valid_from
    DATE_ADD(NOW(), INTERVAL 15 DAY),               -- valid_until
    NOW(),               -- created_at
    NOW(),               -- updated_at
    NULL                -- deleted_at
);