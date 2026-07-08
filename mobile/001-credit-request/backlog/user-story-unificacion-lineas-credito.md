**AS-IS**: Al iniciar la solicitud de crédito, la aplicación pide a Me Service las líneas de crédito disponibles para el usuario. Para responder, Me Service realiza 2 requests separados a Wm Api: uno para obtener las líneas de billetera y otro para obtener las líneas de préstamos, esperando ambas respuestas antes de devolver el resultado combinado a la aplicación.

**TO-BE**: Al iniciar la solicitud de crédito, Me Service obtiene las líneas de billetera y las líneas de préstamos del usuario a través de un único request a Wm Api, que resuelve ambas lecturas en una sola consulta.

# CARD

- **COMO** usuario que solicita un préstamo desde la app móvil
- **QUIERO** que la pantalla de líneas de crédito disponibles cargue más rápido
- **PARA** empezar a solicitar mi crédito sin esperas innecesarias

# Descripción

Hoy, para mostrarle al usuario sus líneas de crédito disponibles (billetera y préstamos), la app depende de 2 requests independientes que Me Service hace a Wm Api. Aunque el usuario ve un solo resultado combinado, por detrás cada request suma su propio tiempo de red y de consulta a base de datos, lo que hace que la pantalla tarde más en mostrarse de lo necesario.

La propuesta es que Wm Api exponga una única forma de consultar ambos tipos de líneas al mismo tiempo, de modo que Me Service haga un solo request en lugar de dos. Esto reduce la cantidad de round-trips entre servicios y el tiempo total que el usuario espera para ver sus líneas de crédito disponibles, sin cambiar la información que finalmente ve en pantalla.

## Fuera de alcance

1. Cambios en la información o el diseño de la pantalla de líneas de crédito que ve el usuario.
2. Cambios en cómo se calculan o definen las líneas de billetera o de préstamos.

## Alcance

1. Unificar en Wm Api las consultas de líneas de billetera y líneas de préstamos en un único endpoint.
2. Actualizar a Me Service para que consulte las líneas de crédito con un solo request a Wm Api en lugar de dos.
3. Validar que la información que recibe la aplicación (y por lo tanto el usuario) sea la misma que con el comportamiento actual.

# Criterios de aceptación

1. La aplicación sigue mostrando al usuario las líneas de billetera y de préstamos disponibles, sin cambios en la información presentada.
2. Me Service obtiene las líneas de billetera y de préstamos mediante un único request a Wm Api, en lugar de los 2 requests actuales.
3. El tiempo de respuesta de la pantalla de líneas de crédito disponibles se reduce respecto al comportamiento actual, al eliminarse un round-trip entre servicios.