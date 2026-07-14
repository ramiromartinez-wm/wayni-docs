# Flujo de autenticación JWT — wm-api

## Librería

**`tymon/jwt-auth` v0.5.*** con backend **`namshi/jose`** para la operación criptográfica.

---

## ¿Dónde decodifica el JWT?

El flujo de decode pasa por tres capas:

1. **Middleware** (`GetUserFromToken` o `SSOAuthMiddleware`) extrae el token del header `Authorization: Bearer <token>`
   - `app/Http/Middleware/GetUserFromToken.php:18`
2. Llama a `JWTAuth::authenticate($token)` / `toUser($token)` → `JWTManager::decode()`
   - `vendor/tymon/jwt-auth/src/JWTManager.php:79`
3. `JWTManager` delega al **`NamshiAdapter::decode()`**
   - `vendor/tymon/jwt-auth/src/Providers/JWT/NamshiAdapter.php:62-74`

```php
// NamshiAdapter.php:62-74
public function decode($token) {
    $jws = JWS::load($token);                          // carga el token
    if (! $jws->verify($this->secret, $this->algo)) {  // VERIFICA FIRMA
        throw new TokenInvalidException('Token Signature could not be verified.');
    }
    return $jws->getPayload();
}
```

> **Nota:** existe un método `parseJWTToken()` en `AuthHelper` (`app/Helpers/AuthHelper.php:77`) que hace `base64_decode` del payload **sin verificar firma**, pero es `private` y nunca se invoca (código muerto).

---

## ¿Valida la firma?

**Sí**, en el flujo normal. `NamshiAdapter::decode()` llama a `$jws->verify($this->secret, $this->algo)` antes de retornar el payload. Si falla, lanza `TokenInvalidException`.

---

## Algoritmo esperado

| Contexto | Algoritmo | Clave |
|---|---|---|
| **App principal** (`jwt.auth`) | `HS256` (HMAC simétrico) | `env('JWT_SECRET_API')`, fallback hardcodeado: `LBHhHqbeCNMzJX3IDgnSyMrk4CJPetrg` |
| **Back-office** (`auth.bo`) | `HS256` | `env('JWT_SECRET_BO')` |
| **SSO** (`jwt.sso_auth`) | `env('SSO_ALGO')` (configurable, típicamente RS256) | Contenido del archivo `env('SSO_PUBLIC_KEY_PATH')` — clave pública asimétrica |

El algoritmo SSO se configura dinámicamente en `SSOConfigMiddleware` — `app/Http/Middleware/SSOConfigMiddleware.php:27-29`.

---

## Claims esperados

Definidos en `config/jwt.php:101`:

```php
'required_claims' => ['iss', 'iat', 'exp', 'nbf', 'sub', 'jti'],
```

| Claim | Descripción |
|---|---|
| `iss` | Issuer (URL de la request) |
| `iat` | Issued at |
| `exp` | Expiración (TTL: 1440 min = 24 h por defecto) |
| `nbf` | Not before |
| `sub` | Identificador del usuario (`id` del modelo `Account`) |
| `jti` | JWT ID (usado para blacklist) |

En el flujo **SSO**, el claim de identificación de usuario se reemplaza por el valor de `env('SSO_AUTH_CLAIM_NAME')` — `app/Http/Middleware/SSOUserAdapter.php:43`.

---

## Otras validaciones

| Validación | Detalle |
|---|---|
| **Expiración (`exp`)** | Validada por la librería; lanza `TokenExpiredException` |
| **Blacklist** | Habilitada por defecto (`JWT_BLACKLIST_ENABLED=true`), almacenada en cache Laravel. Los tokens invalidados (logout, refresh) se rechazan — `JWTManager.php:83` |
| **Usuario en DB** | Tras decodificar y verificar claims, busca el usuario por `sub` en `accounts`; si no existe retorna 404 `user_not_found` |

---

## Middlewares de autenticación

Registrados en `app/Http/Kernel.php:48-58`:

| Alias | Clase | Uso |
|---|---|---|
| `jwt.auth` | `GetUserFromToken` | Autenticación estándar de usuarios (app móvil/web) |
| `jwt.sso_config` | `SSOConfigMiddleware` | Prepara config SSO (swap de secret/algo/claim) |
| `jwt.sso_auth` | `SSOAuthMiddleware` | Autentica via token SSO externo |
| `auth.bo` | `BackOfficeAuthMiddleware` | Swap de secret para back-office, TTL reducido (720 min) |
| `jwt.refresh` | `Tymon\JWTAuth\Middleware\RefreshToken` | Renueva el token |

---

## Flujo SSO (detalle)

`SSOConfigMiddleware` sobreescribe la configuración JWT en runtime antes de que `SSOAuthMiddleware` procese el token:

```php
// SSOConfigMiddleware.php:27-29
Config::set('jwt.secret', file_get_contents(config('wayni.sso_public_key_path')));
Config::set('jwt.algo', config('wayni.sso_algo'));
Config::set('jwt.identifier', config('wayni.sso_auth_claim_name'));
Config::set('jwt.providers.user', SSOUserAdapter::class);
```

`SSOUserAdapter` resuelve el usuario buscando por el claim `SSO_AUTH_CLAIM_NAME` (en lugar del `sub` estándar) — `app/Http/Middleware/SSOUserAdapter.php:43`.

---

## Hallazgos de seguridad

### 1. Secret hardcodeado como fallback

`config/jwt.php:24`:
```php
'secret' => env('JWT_SECRET_API', 'LBHhHqbeCNMzJX3IDgnSyMrk4CJPetrg'),
```
Si `JWT_SECRET_API` no está configurada en producción, todos los entornos quedan con el mismo secret público en el repositorio.

### 2. `parseJWTToken()` sin verificación de firma

`app/Helpers/AuthHelper.php:77-83`:
```php
private function parseJWTToken(Request $request): array
{
    list($header, $payload, $signature) = explode('.', $this->extractTokenFromHeader($request));
    $jsonToken = base64_decode($payload);
    return json_decode($jsonToken, true);
}
```
Decodifica el payload sin verificar la firma. Actualmente es código muerto (nunca invocado), pero representa un riesgo si se llegara a utilizar.

### 3. Firma manual fuera del flujo estándar en `authenticateBySSOToken()`

`app/Http/Controllers/AuthenticateController.php:542-547`:
```php
$jws = new JWS(['typ' => 'JWT', 'alg' => config('jwt.algo')]);
// ...
$jws->setPayload($payload->get())->sign(config('wayni.jwt_secret_api'));
```
Firma el token directamente con `wayni.jwt_secret_api` usando `Namshi\JOSE\JWS` a mano, saliendo del flujo estándar de `tymon/jwt-auth`. Posibles discrepancias si los secrets difieren.

---

## Troubleshooting

### Error: `"El token de autenticación es inválido. Detalle del error: %s: \"Token Signature could not be verified.\""`

Este mensaje es producido por `NamshiAdapter::decode()` (`vendor/tymon/jwt-auth/src/Providers/JWT/NamshiAdapter.php:71`) cuando `$jws->verify()` retorna `false`. Lo captura `SSOAuthMiddleware` y lo formatea via `ErrorHandlingHelper::createExceptionJsonResponse()`.

El `%s` literal en el mensaje es un bug en `resources/lang/es/generics.php:7` — el string `' Detalle del error: %s'` contiene un placeholder que nunca se interpola; el `sprintf` en `ErrorHandlingHelper.php:173` lo usa como argumento, no como sub-template.

#### Causa raíz: singleton resuelto antes del swap de configuración

Al generar tokens con RS256 desde un emisor externo (ej. jwt.io) y verificarlos con la clave pública en `wayni.sso_public_key_path`, el flujo intuitivo parecería correcto:

```
jwt.sso_config → jwt.sso_auth   (orden en routes.php)
```

Sin embargo, **Laravel instancia todas las clases de middleware antes de ejecutar el pipeline**, no una por una. Esto rompe el diseño:

```
1. Laravel instancia SSOAuthMiddleware
   └─ DI resuelve JWTAuth (singleton)
      └─ resuelve JWTManager (singleton)          ← JWTAuthServiceProvider.php:179
         └─ resuelve NamshiAdapter (singleton)    ← JWTAuthServiceProvider.php:135-141
            └─ construido con config('jwt.secret') = HMAC secret del .env  ✗

2. Ejecuta SSOConfigMiddleware::handle()
   └─ Config::set('jwt.secret', file_get_contents(...clave_pública...))  ← ya es tarde

3. Ejecuta SSOAuthMiddleware::handle()
   └─ NamshiAdapter::decode() usa $this->secret = HMAC secret del .env   ✗
      └─ openssl_verify() falla → TokenInvalidException
```

El singleton captura el valor de `jwt.secret` en el constructor (`JWTAuthServiceProvider.php:136`); el `Config::set()` posterior no tiene efecto sobre la instancia ya creada.

#### Soluciones

**Opción A — Invalidar los singletons en `SSOConfigMiddleware`** (mínimo cambio):

```php
// SSOConfigMiddleware.php — después de los Config::set()
app()->forgetInstance('tymon.jwt.provider.jwt');
app()->forgetInstance('tymon.jwt.manager');
app()->forgetInstance('tymon.jwt.auth');
```

Fuerza la re-resolución del grafo completo la próxima vez que `SSOAuthMiddleware` llame a `$this->auth`, momento en que `jwt.secret` ya tiene la clave pública correcta.

**Opción B — Configurar `jwt.secret` en el Service Provider** (más limpio):

Registrar un Service Provider de aplicación que, al hacer boot, lea `wayni.sso_public_key_path` y lo establezca como `jwt.secret` cuando el contexto de la request sea SSO. Evita depender del orden de middlewares.
