# Credit request

## Diagrama de secuencia
![Diagrama](sequence.png)

### Participantes

| Nombre del participante | Nombre corto | Ownership | Descripción |
| --- | --- | --- | --- |
| User | User | - | Usuario final autenticado que interactúa con la aplicación móvil para solicitar un crédito. |
| App Mobile | AM | Frontend | Aplicación móvil que expone la interfaz de usuario del flujo de solicitud de crédito. |
| Me Service | MS | ? | Servicio backend que orquesta el flujo de crédito (líneas, tarjetas, cuenta, OTP) actuando como fachada hacia los demás servicios. |
| Wm Api | WM | Prestamos | Servicio que gestiona las líneas de crédito, opciones de cuotas, tarjetas de débito y la creación de préstamos. |
| Gateway Core | Billetera | Por definir | Servicio core que provee datos de la cuenta del usuario, como el CVU de la cuenta Wayni. |
| Auth Service | Billetera | Por definir | Servicio encargado del envío y validación del código OTP para la confirmación del usuario. |




1. Un usuario, autenticado en la aplicación, selecciona cargar la sección de créditos.
2. La aplicación realiza una llamada `GET /v2/me/credits` del servicio `Me`.
3. El servicio `Me` consulta las líneas de crédito disponibles, para billetera, al servicio `Wm Api`, mediante la llamada `GET /credits/v1/wallet/lines/summaries`.
4. El servicio `Me` consulta las líneas de crédito disponibles, para préstamos, al servicio `Wm Api`, mediante la llamada `GET /credits/v1/loans/lines/summaries`.
5. El servicio `Me` hace un merge de las líneas de crédito obtenidas en (3) y (4) y las retorna.
6. La aplicación renderiza la pantalla de líneas de crédito disponibles.
7. El usuario selecciona una línea de crédito y un monto.
8. La aplicación realiza una llamada `GET /credits/v1/{{product}}/{{credit_type}}/options/{{requested_amount}}`, al servicio `Wm Api`, para obtener las opciones de cuotas disponibles.
9. La aplicación renderiza el listado de cuotas disponibles.
10. El usuario selecciona una opción de cuotas.
11. La aplicación consulta por las tarjetas de débito disponibles, mediante el endpoint GET /me/api/v1/me/loan/card/list, al servicio Me.
12. El servicio Me, recupera las tarjetas de débito del usuario realizando una request GET /v3/card al servicio WmApi.

