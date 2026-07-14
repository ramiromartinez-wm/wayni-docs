# Key concepts

Glosario de los conceptos clave utilizados en la documentación de arquitectura de `wm-foundation-net`.

## Glosario

| Concepto |
| --- |
| [Composition Root](#composition-root) |
| [Dependency Injection (DI)](#dependency-injection-di) |
| [Extension methods (métodos de extensión)](#extension-methods-métodos-de-extensión) |
| [Inversión de Dependencias (Dependency Inversion Principle)](#inversión-de-dependencias-dependency-inversion-principle) |
| [Módulo](#módulo) |
| [Ports & Adapters (Arquitectura Hexagonal)](#ports--adapters-arquitectura-hexagonal) |
| [Shared Kernel](#shared-kernel) |

### Composition Root

Punto único de la aplicación (la aplicación consumidora del framework) donde se ensamblan y registran todas las dependencias en el contenedor de Inyección de Dependencias. Es el lugar donde cada módulo del framework se "engancha" al ciclo de vida de la aplicación mediante sus métodos de extensión.

### Dependency Injection (DI)

Patrón de diseño mediante el cual un objeto recibe sus dependencias desde el exterior (típicamente a través de un contenedor de IoC) en lugar de crearlas internamente. En este framework, es el mecanismo elegido para componer los distintos módulos en la aplicación consumidora, en lugar de una arquitectura tipo Ports & Adapters.

### Inversión de Dependencias (Dependency Inversion Principle)

Principio por el cual los módulos de alto nivel no dependen de implementaciones concretas de otros módulos, sino de abstracciones (interfaces) declaradas en un punto común (`Core`). Es el mecanismo que permite el aislamiento entre módulos sin acoplarlos directamente entre sí.

### Shared Kernel

Núcleo compartido (`Core`) que expone únicamente abstracciones, interfaces y tipos base genuinamente transversales a todo el framework. No contiene lógica de negocio ni implementaciones concretas; su función es evitar el acoplamiento directo entre módulos, actuando como punto común de contratos.

### Extension methods (métodos de extensión)

Mecanismo del lenguaje C# utilizado por cada módulo para exponer su configuración de Inyección de Dependencias (típicamente dentro de un directorio `DependencyInjection`), permitiendo que la aplicación consumidora los registre de forma selectiva y sencilla en el Composition Root. Sigue la filosofía de diseño de `Microsoft.Extensions.*` en .NET.

### Ports & Adapters (Arquitectura Hexagonal)

Patrón arquitectónico orientado a aislar la lógica de dominio de negocio de la infraestructura circundante. Fue descartado como arquitectura global del framework por no existir dominio de negocio propio (el framework es infraestructura de punta a punta), aunque se recomienda su uso puntual dentro de componentes específicos (por ejemplo, para integrar múltiples proveedores de identidad de forma agnóstica).

### Módulo

Unidad de software independiente y autocontenida que resuelve una preocupación transversal concreta (logging, observabilidad, multitenancy, autenticación, etc.). Se distribuye como paquete propio, se registra vía DI en el Composition Root, y tiene prohibido acoplarse directamente a otros módulos.
