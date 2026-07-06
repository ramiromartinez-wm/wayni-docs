# Solicitud de prestamo

## Descripcion del flujo

### Participantes

| Nombre del participante | Nombre corto | Ownership | Descripción |
| --- | --- | --- | --- |
| User | User | - | Usuario final autenticado que interactúa con la aplicación móvil para solicitar un crédito. |
| App Mobile | AM | Frontend | Aplicación móvil que expone la interfaz de usuario del flujo de solicitud de crédito. |
| Me Service | MS | ? | Servicio backend que orquesta el flujo de crédito (líneas, tarjetas, cuenta, OTP) actuando como fachada hacia los demás servicios. |
| Wm Api | WM | Prestamos | Servicio que gestiona las líneas de crédito, opciones de cuotas, tarjetas de débito y la creación de préstamos. |
| Gateway Core | Billetera | Por definir | Servicio core que provee datos de la cuenta del usuario, como el CVU de la cuenta Wayni. |
| Auth Service | Billetera | Por definir | Servicio encargado del envío y validación del código OTP para la confirmación del usuario. |

### Diagrama de secuencia
![Diagrama](sequence.png)


### Descripcion

#### 1. Obtener líneas de crédito
La aplicación (`AM`) solicita a `Me Service` las líneas de crédito disponibles para el usuario. `Me Service` consulta a su vez a `Wm Api` las líneas de billetera y las líneas de préstamos, y devuelve a la aplicación el resultado combinado.

**🌐 Endpoints relacionados**

| Paso | Servicio | Método | Endpoint |
| --- | --- | --- | --- |
| 1 | Me Service | GET | /me/api/v2/me/credits |
| 2 | Wm Api | GET | /credits/v1/wallet/lines/summaries |
| 3 | Wm Api | GET | /credits/v1/loans/lines/summaries |

**💡 Oportunidades de mejora**

| N° | Mejora | Criticidad |
| --- | --- | --- |
| 1 | Unificar los dos endpoints de `Wm Api` (líneas de billetera y líneas de préstamos) en una única llamada HTTP que resuelva ambas lecturas en una sola consulta a base de datos, reduciendo la cantidad de round-trips y mejorando los tiempos del flujo. | 🟡 Media |

#### 2. Simular cuotas del crédito
Una vez que el usuario selecciona el monto y la línea de crédito, la aplicación consulta directamente a `Wm Api` las opciones de cuotas disponibles para esa combinación.

**🌐 Endpoints relacionados**

| Paso | Servicio | Método | Endpoint |
| --- | --- | --- | --- |
| 1 | Me Service | GET | /credits/v1/wallet/personal-loan/options/{amount} |
| 2 | Wm Api | GET | /credits/v1/{{product}}/{{credit_type}}/options/{{requested_amount}} |

**💡 Oportunidades de mejora**

| N° | Mejora | Criticidad |
| --- | --- | --- |
| 1 | Modificar la construcción del balance crediticio del usuario para el producto préstamos, de forma que sea compatible con la consulta de cuotas. | 🔴 Critico |

#### 3. Obtener tarjeta de débito del usuario
La aplicación solicita a `Me Service` la tarjeta de débito asociada al usuario. `Me Service` reenvía la consulta a `Wm Api`, que responde con los datos de la tarjeta (o su ausencia), permitiendo mostrar los detalles existentes o iniciar el alta de una nueva tarjeta.

**🌐 Endpoints relacionados**

| Paso | Servicio | Método | Endpoint |
| --- | --- | --- | --- |
| 1 | Me Service | GET | /me/api/v1/me/loan/card/list |
| 2 | Wm Api | GET | /v3/card |

**💡 Oportunidades de mejora**

| N° | Mejora | Criticidad |
| --- | --- | --- |
| 1 | No almacenar las tarjetas de débito en nuestra base de datos, sino delegar su almacenamiento en un proveedor de tokenización. | 🔴 Alta |

#### 4. Validar tarjeta de débito
Tras aceptar el método de pago, la aplicación pide a `Me Service` validar la tarjeta de débito seleccionada. `Me Service` delega la validación en `Wm Api`.

**🌐 Endpoints relacionados**

| Paso | Servicio | Método | Endpoint |
| --- | --- | --- | --- |

**💡 Oportunidades de mejora**

| N° | Mejora | Criticidad |
| --- | --- | --- |
| 1 | Reemplazar la autorización por la pre autorización, con la finalidad de evitar el flujo de anulación. | 🟡 Media |

#### 5. Obtener cuenta Wayni (CVU)
La aplicación solicita a `Me Service` la cuenta Wayni del usuario. `Me Service` consulta el CVU correspondiente a `Gateway Core` y lo retorna a la aplicación para mostrar la pantalla de confirmación.

**🌐 Endpoints relacionados**

| Paso | Servicio | Método | Endpoint |
| --- | --- | --- | --- |

**💡 Oportunidades de mejora**

| N° | Mejora | Criticidad |
| --- | --- | --- |

#### 6. Enviar código OTP
Cuando la confirmación no se realiza mediante biometría, la aplicación solicita a `Me Service` el envío de un OTP. `Me Service` delega el envío en `Auth Service`, y la aplicación muestra la pantalla para que el usuario ingrese el código recibido.

**🌐 Endpoints relacionados**

| Paso | Servicio | Método | Endpoint |
| --- | --- | --- | --- |

**💡 Oportunidades de mejora**

| N° | Mejora | Criticidad |
| --- | --- | --- |

#### 7. Intento de creación de préstamo
Finalmente, la aplicación solicita a `Me Service` intentar la creación del préstamo. `Me Service` envía la solicitud de creación a `Wm Api`, que retorna el préstamo generado para que la aplicación muestre el estado y los detalles al usuario.

**🌐 Endpoints relacionados**

| Paso | Servicio | Método | Endpoint |
| --- | --- | --- | --- |

**💡 Oportunidades de mejora**

| N° | Mejora | Criticidad |
| --- | --- | --- |

