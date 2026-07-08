**AS-IS**: Al validar la tarjeta de débito seleccionada para el préstamo, el sistema realiza una **autorización** completa sobre la tarjeta (retiene el monto como si fuera a efectivizarse un cobro real) y, ya que en este paso solo se busca comprobar que la tarjeta es válida y operativa, inmediatamente después se dispara una segunda operación de **(refund)** para liberar ese monto retenido. Esto implica 2 requests contra el proveedor externo (Payway Ingenico) en lugar de 1, y si el refund falla, el sistema debe reintentarla, sumando requests adicionales y lógica de negocio extra para sostener esos reintentos hasta confirmar que el monto fue liberado.

**TO-BE**: Al validar la tarjeta de débito, el sistema realiza una **pre autorización** (también llamada autorización en frío), una operación que verifica que la tarjeta existe, está activa y tiene capacidad para operar, pero sin retener ni comprometer el monto. Al no reservar fondos, no existe nada que anular después, eliminando la necesidad del segundo request de reverso y de toda la lógica de reintentos asociada.

# CARD

- **COMO** usuario que solicita un préstamo desde la app móvil
- **QUIERO** que la validación de mi tarjeta de débito sea más rápida y confiable
- **PARA** avanzar en el flujo de solicitud de crédito sin demoras ni errores innecesarios

# Descripción

Actualmente, para confirmar que la tarjeta de débito ingresada por el usuario es válida, el sistema hace una autorización real sobre la tarjeta (equivalente a reservar el dinero de una compra) y luego debe anular esa reserva con un segundo request, ya que en realidad no se busca cobrar nada en este paso, solo confirmar que la tarjeta funciona.

Este enfoque de "autorización + reverso" tiene dos requests contra el proveedor externo (Payway Ingenico) en lugar de uno solo, la latencia del flujo aumenta, ya que el usuario debe esperar a que ambas operaciones se completen, y si la anulación falla, se dispara lógica de reintentos, con requests adicionales, mayor probabilidad de errores y peor experiencia para el usuario.

La propuesta es reemplazar este mecanismo por una **pre autorización**, que permite validar que la tarjeta es correcta y está habilitada sin necesidad de reservar fondos. Al no haber una reserva de dinero, no hay nada que revertir después, por lo que se elimina por completo el segundo request y toda la lógica de reintentos asociada al reverso.

## Fuera de alcance

1. Cambios en la validación de tarjetas de crédito (esta mejora aplica solo a tarjetas de débito).
3. Cambios en el proveedor externo (Payway Ingenico) más allá de utilizar la operación de pre autorización que este ya expone.

## Alcance

1. Reemplazar la operación de autorización por pre autorización al validar la tarjeta de débito seleccionada por el usuario.
2. Eliminar el request de anulación/reverso posterior a la validación, dado que deja de ser necesario.
3. Eliminar la lógica de reintentos asociada a fallos en la anulación, ya que ese escenario deja de existir.
4. Validar que el resultado que recibe el usuario (tarjeta válida / inválida) se mantenga sin cambios desde su perspectiva.

# Criterios de aceptación

1. Al validar una tarjeta de débito, el sistema utiliza pre autorización en lugar de autorización, sin reservar fondos sobre la tarjeta del usuario.
2. El flujo de validación ya no ejecuta ningún request de devolución posterior.
3. No existe lógica de reintentos por fallos de anulación, dado que esa operación deja de formar parte del flujo.
4. El usuario continúa recibiendo el mismo resultado de validación (tarjeta válida o inválida) que con el comportamiento actual.
5. El tiempo de respuesta del paso de validación de tarjeta se reduce respecto al comportamiento actual, al eliminarse un request de la cadena.