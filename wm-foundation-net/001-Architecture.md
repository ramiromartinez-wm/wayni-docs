# Diseño Arquitectónico Modular del Foundation Framework

## Estado

Borrador

## Contexto

Se requiere definir el diseño arquitectónico de una librería .NET Core que actúa como *foundation framework* para futuros microservicios de la organización. Se espera que la librería, a desarrollar, resuelva problemas transversales del desarrollo (logging estructurado, observabilidad, multitenancy, autenticación) mediante módulos (wrappers) que se enganchan al ciclo de vida de la aplicación.

## Conceptos clave

- [Ports & Adapters (Arquitectura Hexagonal)](000-Key-Concepts.md#ports--adapters-arquitectura-hexagonal)
- [Dependency Injection (DI)](000-Key-Concepts.md#dependency-injection-di)
- [Módulo](000-Key-Concepts.md#módulo)
- [Composition Root](000-Key-Concepts.md#composition-root)
- [Extension methods (métodos de extensión)](000-Key-Concepts.md#extension-methods-métodos-de-extensión)
- [Shared Kernel](000-Key-Concepts.md#shared-kernel)
- [Inversión de Dependencias (Dependency Inversion Principle)](000-Key-Concepts.md#inversión-de-dependencias-dependency-inversion-principle)

## Decisión

Tras descartar el patrón de Puertos y Adaptadores (*Ports & Adapters*) como arquitectura global del *framework*, se optó por un diseño orientado a módulos compuestos mediante Inyección de Dependencias (DI). Bajo este enfoque, cada módulo constituye un paquete independiente que se registra en el contenedor de dependencias del *Composition Root* (la aplicación consumidora) a través de métodos de extensión (*extension methods*), alineándose con la filosofía de diseño de `Microsoft.Extensions.*` en .NET.

### Estructura del framework

A continuación, se detalla el *scaffolding* propuesto para el *framework*. Esta organización física refleja la separación lógica de responsabilidades: el núcleo compartido (`Core`) actúa como un *Shared Kernel* que expone únicamente abstracciones y contratos comunes, mientras que cada módulo funcional o técnico (como `Foo` o `Baz`) se mantiene aislado y autocontenido. Cada módulo expone su configuración de inyección de dependencias dentro del directorio `DependencyInjection`, encapsulando allí los métodos de extensión necesarios para que la aplicación consumidora los registre de forma selectiva y sencilla.

```text
Wayni
└── Foundation
    ├── Core (shared kernel)
    │   └── Abstractions (common interfaces)
    └── Foo (module)
        └── DependencyInjection (module configuration)
    └── Baz (module)
        └── DependencyInjection (module configuration)
```

### Principios

A partir de la estructura propuesta, se establecen las siguientes directrices de diseño que deben respetarse estrictamente al desarrollar componentes:

- **Pureza de abstracción en `Core`:** Este módulo debe estar libre de lógica de negocio o implementaciones concretas. Con el fin de evitar que actúe como un "cajón de sastre" (un contenedor desordenado de utilidades), su propósito se limita exclusivamente a albergar contratos, interfaces y tipos base que sean genuina y estrictamente transversales a todo el *framework*.

- **Aislamiento e independencia de módulos:** Cada módulo representa una unidad de software independiente y autónoma. Queda estrictamente prohibido el acoplamiento directo entre módulos (un módulo nunca debe referenciar el paquete concreto de otro). Si un módulo requiere consumir capacidades expuestas por un tercero, deberá hacerlo abstrayendo la comunicación mediante una interfaz declarada en `Core`, asegurando así un diseño basado en Inversión de Dependencias.

```text
┌───────────────────┐           ┌────────────┐                 ┌────────────┐
│  Composition Root │ ──uses──> │  Module X  │ ──implements──> │    Core    │
└───────────────────┘           └────────────┘                 └────────────┘
```

## Justificación

*Ports & Adapters* existe para aislar **lógica de dominio** de la infraestructura que la rodea. Este framework no tiene dominio de negocio: es infraestructura de punta a punta (wrappers sobre Serilog, OpenTelemetry, el pipeline HTTP, etc.). Aplicar hexagonal completa resulta redundante en este escenario.

Aunque se desestimó el uso de *Ports & Adapters* como arquitectura global del *framework*, su implementación sigue siendo altamente recomendable dentro de componentes específicos. Este enfoque facilita, por ejemplo, la integración modular y agnóstica de múltiples proveedores de identidad.

## Consecuencias

### Ventajas (impacto positivo)

- **Prevención de la sobreingeniería:** Se evita la introducción de capas abstractas redundantes (como entidades, casos de uso o puertos) en escenarios donde no existe una lógica de negocio compleja que requiera ser aislada o protegida.

- **Alineación con el estándar de la plataforma:** Al respetar las convenciones nativas y ampliamente adoptadas de la comunidad .NET, se minimiza la curva de adopción y se facilita la incorporación de nuevos desarrolladores al proyecto.

- **Autonomía y flexibilidad modular:** Al establecer únicamente un estándar estructural mínimo para el interior de los módulos, se otorga a los equipos de desarrollo la libertad de implementar el diseño arquitectónico que mejor resuelva las necesidades particulares de cada componente.

- **Bajo acoplamiento entre módulos:** se puede agregar, quitar o reemplazar un módulo sin que el resto del framework se entere.

### Desventajas (impacto negativo)

- **Esfuerzo de gobernanza en `Core`:** Mantener la pureza de este módulo requerirá revisiones de código estrictas para evitar que se convierta en un "cajón de sastre".

- **Gestión de dependencias internas:** Si una abstracción en `Core` cambia, afectará directamente a múltiples módulos, lo que exige una estrategia clara de versionado de paquetes.
