**AS-IS**: Al consultar la tarjeta de débito del usuario, Wm Api responde con los datos de la tarjeta almacenados en nuestra propia base de datos. Si bien este almacenamiento cumple con los estándares de compliance PCI, implica que la información de la tarjeta sigue existiendo en una base de datos propia, lo que nos mantiene expuestos: un eventual robo de esos datos podría ser utilizado para intentos de phishing contra nuestros usuarios, aún cuando el almacenamiento en sí sea compliant.

**TO-BE**: Al consultar la tarjeta de débito del usuario, Wm Api obtiene los datos directamente desde un proveedor de tokenización externo especializado, en lugar de leerlos de una base de datos propia. Los datos sensibles de la tarjeta dejan de almacenarse en nuestra infraestructura, reduciendo la exposición ante un eventual robo de datos.

# Card

- **COMO** usuario que solicita un préstamo desde la app móvil
- **QUIERO** que los datos de mi tarjeta de débito estén resguardados de la forma más segura posible
- **PARA** estar protegido frente a robos de información que puedan derivar en intentos de fraude o phishing en mi contra

# Descripción

Actualmente, cuando la aplicación necesita mostrar la tarjeta de débito asociada al usuario, Wm Api responde con datos que están almacenados en nuestra propia base de datos. Este almacenamiento cumple con los requisitos de compliance PCI, pero eso no elimina el riesgo: mientras los datos de la tarjeta existan en una base propia, un eventual robo de esa base podría exponer información suficiente para que terceros la usen en campañas de phishing contra nuestros usuarios, haciéndose pasar por nosotros o por otras entidades de confianza.

La propuesta es dejar de almacenar los datos de la tarjeta de débito en nuestra base de datos, y en su lugar leerlos y almacenarlos directamente en un proveedor de tokenización especializado. De esta forma, aunque nuestra base de datos fuera comprometida, no habría datos de tarjetas reales para robar, ya que estos residen exclusivamente en la infraestructura del proveedor de tokenización.

## Fuera de alcance

1. Cambios en la experiencia del usuario al ver o cargar su tarjeta de débito en la aplicación.
2. Cambios en el proceso de validación de la tarjeta (autorización/pre autorización).
3. Selección técnica del proveedor de tokenización (se asume que ya existe o será evaluado por separado).

## Alcance

1. Migrar el almacenamiento de los datos de la tarjeta de débito desde nuestra base de datos hacia un proveedor de tokenización.
2. Actualizar la consulta de tarjeta de débito para que Wm Api obtenga los datos desde el proveedor de tokenización en lugar de la base propia.
3. Eliminar de nuestra base de datos los datos de tarjeta que ya no sean necesarios una vez migrados.

# Criterios de aceptación

1. Los datos de la tarjeta de débito del usuario ya no se almacenan en nuestra base de datos propia.
2. Al consultar la tarjeta de débito, Wm Api obtiene la información desde el proveedor de tokenización.
3. La aplicación sigue mostrando al usuario los datos de su tarjeta de débito (o su ausencia) sin cambios respecto al comportamiento actual.
4. Un eventual acceso no autorizado a nuestra base de datos ya no permite obtener datos utilizables de la tarjeta de débito del usuario.