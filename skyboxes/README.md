# XeroHub skyboxes

Sube la carpeta `skyboxes` completa a tu repositorio (puedes arrastrar todos los archivos juntos con GitHub Desktop).

Estructura esperada:

- `skyboxes/manifest.json`
- `skyboxes/<pack>/bk.png`
- `skyboxes/<pack>/dn.png`
- `skyboxes/<pack>/ft.png`
- `skyboxes/<pack>/lf.png`
- `skyboxes/<pack>/rt.png`
- `skyboxes/<pack>/up.png`

El script descarga solo el pack seleccionado y lo guarda en caché local.

Default del Lua:
`https://raw.githubusercontent.com/OnyxDevv/Onyx-web/refs/heads/main/skyboxes`

Puedes cambiarlo antes de ejecutar:
`getgenv().XERO_SKYBOX_BASE_URL = "https://raw.githubusercontent.com/USUARIO/REPO/refs/heads/main/skyboxes"`
