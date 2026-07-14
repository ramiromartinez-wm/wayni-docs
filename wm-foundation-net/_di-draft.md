
 
```
Microservicio consumidor
        │
   ┌────┼────┬────────────┐
   ▼    ▼    ▼            ▼
Logging Observability MultiTenancy Auth
   │    │    │            │
   └────┴────┴────────────┘
              ▼
     Core / Abstractions
   (contratos compartidos, sin lógica)
```
 
## 4. Inyección de dependencias interna entre módulos
 
### 4.1 Comunicación cruzada sin acoplamiento
 
Los módulos colaboran entre sí a través de interfaces definidas en `Core`, nunca por referencia directa. Ejemplo: `MultiTenancy` contribuye un enriquecedor de logs sin que `Logging` sepa que `MultiTenancy` existe.
 
```csharp
// Framework.Core.Abstractions
public interface ILogEnricher
{
    void Enrich(ILogContext context);
}
```
 
```csharp
// Framework.MultiTenancy
services.TryAddScoped<ITenantContextAccessor, TenantContextAccessor>();
services.AddSingleton<ILogEnricher, TenantLogEnricher>(); // Logging nunca referencia este tipo
```
 
```csharp
// Framework.Logging — consume todo lo que exista, sin saber quién lo aportó
var enrichers = sp.GetServices<ILogEnricher>();
```
 
`TryAdd*` se usa para registrar defaults que un módulo posterior puede pisar sin generar duplicados; el patrón `IEnumerable<T>` (vía `GetServices<T>`) es el punto de extensión que permite que cualquier módulo "contribuya" a otro sin acoplarse a él.
 
### 4.2 Estrategia de composición: builder explícito
 
Se evaluaron tres alternativas:
 
| Estrategia | Estado | Motivo |
|---|---|---|
| Auto-discovery total (reflection) | Descartada | Riesgo de módulos "invisibles" por carga perezosa de ensamblados (`AppDomain.CurrentDomain.GetAssemblies()` no garantiza que un ensamblado referenciado esté cargado en memoria); falla de forma silenciosa; sin IntelliSense; difícil de debuggear ("¿por qué está registrado esto?"). |
| Híbrido (auto-discovery + override manual) | Descartada | Combina la complejidad de ambos enfoques sin eliminar el riesgo de la reflection. |
| **Builder explícito** | **Elegida** | El dev ve exactamente qué módulos participan, con IntelliSense y errores de compilación si falta un método. Permite fail-fast con validación de prerequisites entre módulos. |
 
**Contrato base:**
 
```csharp
// Framework.Core.Abstractions
public interface IFrameworkBuilder
{
    IServiceCollection Services { get; }
    IConfiguration Configuration { get; }
}
```
 
**Punto de entrada único:**
 
```csharp
// Framework.Core
public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddFoundationFramework(
        this IServiceCollection services,
        IConfiguration configuration,
        Action<IFrameworkBuilder> configureModules)
    {
        var builder = new FrameworkBuilder(services, configuration);
        configureModules(builder);
        return services;
    }
}
```
 
**Cada módulo extiende `IFrameworkBuilder`, no `IServiceCollection` directamente** (esto mantiene la superficie de composición bajo control del framework):
 
```csharp
// Framework.Logging
public static IFrameworkBuilder AddLogging(this IFrameworkBuilder b)
{
    b.Services.AddSingleton<ILoggerFactory>(sp =>
        BuildLoggerFactory(sp.GetServices<ILogEnricher>(), b.Configuration));
    return b;
}
 
// Framework.MultiTenancy
public static IFrameworkBuilder AddMultiTenancy(this IFrameworkBuilder b)
{
    b.Services.TryAddScoped<ITenantContextAccessor, TenantContextAccessor>();
    b.Services.AddSingleton<ILogEnricher, TenantLogEnricher>();
    return b;
}
```
 
**Uso del lado del consumidor:**
 
```csharp
services.AddFoundationFramework(configuration, modules => modules
    .AddLogging()
    .AddMultiTenancy()
    .AddAuth());
```
 
Nadie escribe a mano el registro de `ILogEnricher`. El dev decide *qué* módulos usar; la librería decide *cómo* se enchufan entre sí.
 
### 4.3 Validación de prerequisites entre módulos (fail fast)
 
```csharp
public static IFrameworkBuilder AddAuth(this IFrameworkBuilder b)
{
    if (!b.Services.Any(d => d.ServiceType == typeof(ITenantContextAccessor)))
        throw new InvalidOperationException(
            "AddAuth() requiere haber llamado antes a AddMultiTenancy().");
 
    b.Services.AddAuthentication(/* ... */);
    return b;
}
```
 
### 4.4 Pendiente: pipeline de middleware
 
El orden de registro en el contenedor de DI no importa (resolución perezosa), pero el orden de los middlewares HTTP sí. Se planea espejar el mismo patrón de builder explícito también para el pipeline:
 
```csharp
app.UseFoundationFramework(pipeline => pipeline
    .UseTenantResolution()
    .UseRequestLogging());
```
 
*(Diseño pendiente de cerrar en una próxima sesión — acá el orden de los `.Use...()` sí es funcionalmente relevante, a diferencia del registro en el contenedor.)*
 
## 5. Configuración
 
### 5.1 Un único `IConfiguration`, sin importar el origen
 
En .NET, toda fuente de configuración (`appsettings.json`, archivo propio, variables de entorno, Key Vault) termina fusionada en un solo `IConfiguration`. No existe — ni hace falta — un sistema de configuración paralelo para el framework.
 
```
appsettings.json ──┐
framework.json  ───┼──► IConfiguration unificada ──► cada módulo lee su sección
env vars/Key Vault ─┘
```
 
### 5.2 Convención: un nodo por módulo
 
`Framework:Logging`, `Framework:MultiTenancy`, `Framework:Auth`, etc.
 
### 5.3 Options pattern con fail-fast
 
```csharp
// Framework.MultiTenancy
public sealed class MultiTenancyOptions
{
    public const string SectionName = "Framework:MultiTenancy";
 
    [Required]
    public string ConnectionString { get; init; } = string.Empty;
    public string ResolutionStrategy { get; init; } = "Header";
}
```
 
```csharp
public static IFrameworkBuilder AddMultiTenancy(this IFrameworkBuilder b)
{
    b.Services.AddOptions<MultiTenancyOptions>()
        .Bind(b.Configuration.GetSection(MultiTenancyOptions.SectionName))
        .ValidateDataAnnotations()
        .ValidateOnStart(); // si falta el connection string, revienta al arrancar, no en runtime
 
    b.Services.TryAddScoped<ITenantContextAccessor, TenantContextAccessor>();
    return b;
}
```
 
Consumo dentro del módulo, siempre vía `IOptions<T>`, nunca leyendo `IConfiguration` directamente:
 
```csharp
public sealed class TenantContextAccessor : ITenantContextAccessor
{
    private readonly MultiTenancyOptions _options;
    public TenantContextAccessor(IOptions<MultiTenancyOptions> options) => _options = options.Value;
}
```
 
### 5.4 Archivo de configuración propio (opcional)
 
```csharp
public static IConfigurationBuilder AddFoundationFrameworkConfiguration(
    this IConfigurationBuilder builder, string? path = null, bool optional = true)
{
    return builder
        .AddJsonFile(path ?? "foundationframework.json", optional, reloadOnChange: true)
        .AddEnvironmentVariables(prefix: "FRAMEWORK_");
}
```
 
```csharp
// Program.cs del consumidor
builder.Configuration.AddFoundationFrameworkConfiguration();
```
 
### 5.5 Manejo de secrets
 
Un valor como el connection string de Postgres es una credencial, esté en el archivo que esté. Regla adoptada:
 
- El archivo del framework (versionado en el repo) define **schema y valores no sensibles** (estrategia de resolución, timeouts, retry policy).
- El valor real de connection strings / credenciales se inyecta vía **variables de entorno en producción** y **`dotnet user-secrets` en desarrollo local** — ambos terminan pisando la misma clave (`Framework:MultiTenancy:ConnectionString`) en el `IConfiguration` unificado. El módulo no distingue el origen.
## 6. Próximos pasos
 
1. Cerrar el diseño del pipeline de middleware (`UseFoundationFramework`), donde el orden sí es funcionalmente relevante.
2. Empezar la implementación concreta por el módulo de **Logging** (menos dependencias externas, y el primer punto de extensión — `ILogEnricher` — que el resto de los módulos van a consumir).
3. Definir el schema completo de `MultiTenancyOptions`, incluyendo el manejo de secrets en cada entorno.
