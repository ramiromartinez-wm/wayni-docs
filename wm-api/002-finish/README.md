- Usa otro JWT, con otra firma y algoritmo.

1. Validación cuenta bancaria
    - Si es CBU externo debe existir en la tabla banking (columna cbu, approved = 1, deleted_at NULL)
2. Validación TDD
    - Se fija en la tabla credit_cards (validated = 1)
3. Foto frontal del DNI aprobada y ¿datos biometricos parametrizados (revisar)?
pasando un atributo biometric: true y user_information.front_document_approved = 0 -> vale y pasa.


│ P (front_approved) │ B (biometric efectivo) │                  Resultado                  │                                                                                      
  ├────────────────────┼────────────────────────┼─────────────────────────────────────────────┤                                                                                      
  │ V                  │ V                      │ No entra                                    │                                                                                      
  ├────────────────────┼────────────────────────┼─────────────────────────────────────────────┤                                                                                      
  │ V                  │ F                      │ No entra                                    │                                                                                      
  ├────────────────────┼────────────────────────┼─────────────────────────────────────────────┤                                                                                      
  │ F                  │ V                      │ No entra                                    │                                                                                      
  ├────────────────────┼────────────────────────┼─────────────────────────────────────────────┤                                                                                      
  │ F                  │ F                      │ Entra → error check_front_identity_document │ 
4. Verificacion de contacto (contact_data = 1) y domicilio (address_verified = 1) (credit_rating).
5. Verificacion de fraude


Delivery Point ? bank transfer u otra ?


{
    "entity": "loanRequest",
    "code": 200,
    "result": {
        "id": 31252,
        "state": 2,
        "name": "Wayni Móvil - #0702041056.525",
        "slug": "wayni-movil-0702041056525",
        "description": "<p>Wayni Móvil - #0702041056.525</p>",
        "was_created_in_membership": false,
        "amount": 3000,
        "original_amount": 3000,
        "final_amount": 5435,
        "original_final_amount": 5435,
        "funded": 0,
        "interest_rate": 3.7,
        "original_interest_rate": 3.7,
        "tea": 41.9469,
        "cft": 4.477,
        "original_cft": 4.477,
        "days": 90,
        "cashout_fee": 0,
        "cashin_fee": 0,
        "insurance_amount": 0,
        "tax_amount": 422.56,
        "cycle_quantity": 30,
        "installment_count": 3,
        "payment": 1812,
        "friends_count": 0,
        "publish_date": "2026-07-02 00:00:00",
        "expiration_date": "2026-08-01 00:00:00",
        "start_date": "2026-07-02",
        "close_date": null,
        "returned_amount": 0,
        "exchange_approve": "0.00000000",
        "dolar_reference": 1,
        "credit_structure_id": 525,
        "point_of_sale_delivery": 13,
        "transference_bank_id": 70,
        "amount_delivery": 3000,
        "pending_amount": 5435,
        "administrative_fee": 0,
        "state_name": "Aprobado",
        "state_slug": "send",
        "state_info": "Estamos revisando la documentación subida y te enviaremos una notificación cuando puedas retirar el dinero.",
        "type": "option",
        "delivery_type": "bank-transfer",
        "bank": {
            "bank": "BBVA BANCO FRANCES S.A.",
            "account_type_id": 1,
            "account_holder": "Sandra Chavarria",
            "cbu": "0170274540000002715179",
            "legal_number": null
        },
        "card": {
            "card_type_id": 2,
            "number": "4398**********3308",
            "brand_id": 2,
            "bank": "BANCO DE LA PROVINCIA DE BUENOS AIRES",
            "holder": "Silvana Sandra Gonzalez",
            "expiration_date": "2019-05-01 00:00:00",
            "brand": "visa"
        },
        "pod": {
            "id": 13,
            "name": "TRANSFERENCIA BANCARIA",
            "city": "CABA",
            "address": "Deberá enviar CBU, CUIT y Nro de cuenta",
            "open": "24hs.",
            "full": "Deberá enviar CBU, CUIT y Nro de cuenta",
            "lat": "-34.59616710",
            "lon": "-58.37313880",
            "phone": "53521254"
        },
        "has_membership_enabled": false
    }
}

--

1. Validación de payload.
2. CheckRenewalClient (lineas 1888 - 1912) OK
3. Validación de datos del payload (1916 - 1939)
4. Verificación de cuenta bancaria 1941 - 1953 OK
5. Verificación de tarjeta de débito 1954 - 1964 OK
6. Verificación biométrica 1967 - 1973
7. Verificación de domicilio 1975 - 1981
8. Verificación de número telefónico 1983 - 1989
9. Verificación de deudores 1991 - 2001
10. Verificación de fraude 2003 - 2018