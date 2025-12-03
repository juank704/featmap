# Guía de Despliegue en Digital Ocean

Esta guía te ayudará a desplegar Featmap en tu droplet de Digital Ocean (68.183.175.19).

## Requisitos Previos

- Acceso SSH a tu droplet de Digital Ocean
- Docker y Docker Compose instalados en el droplet

## Paso 1: Conectarse al Droplet

```bash
ssh root@68.183.175.19
# O si usas un usuario específico:
# ssh tu_usuario@68.183.175.19
```

## Paso 2: Instalar Docker y Docker Compose (si no están instalados)

```bash
# Actualizar el sistema
apt update && apt upgrade -y

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Instalar Docker Compose
apt install docker-compose -y

# Verificar instalación
docker --version
docker-compose --version
```

## Paso 3: Preparar el Directorio de Trabajo

```bash
# Crear directorio para featmap
mkdir -p /opt/featmap
cd /opt/featmap
```

## Paso 4: Subir los Archivos del Proyecto

Desde tu máquina local, puedes usar `scp` o `rsync` para subir los archivos:

### Opción A: Usando SCP (desde tu máquina local)

```bash
# Desde tu máquina local, en el directorio del proyecto
scp -r . root@68.183.175.19:/opt/featmap/
```

### Opción B: Usando Git (recomendado)

```bash
# En el droplet
cd /opt/featmap
git clone <tu-repositorio> .
# O si ya tienes el código, simplemente clónalo
```

### Opción C: Usando rsync (más eficiente)

```bash
# Desde tu máquina local
rsync -avz --exclude 'data' --exclude '.git' . root@68.183.175.19:/opt/featmap/
```

## Paso 5: Configurar Variables de Entorno

```bash
# En el droplet
cd /opt/featmap

# Crear archivo .env desde el ejemplo
cp .env.example .env

# Editar el archivo .env con tus valores
nano .env
```

Asegúrate de configurar:
- `FEATMAP_DB`: Nombre de la base de datos
- `FEATMAP_DB_USER`: Usuario de PostgreSQL
- `FEATMAP_DB_PASSWORD`: Contraseña segura para PostgreSQL
- `FEATMAP_HTTP_PORT`: Puerto (por defecto 5000)

## Paso 6: Configurar conf.json para Producción

```bash
# Editar el archivo de configuración
nano config/conf.json
```

Actualiza los siguientes valores:

```json
{
  "appSiteURL": "http://68.183.175.19:5000",
  "dbConnectionString": "postgresql://featmap_user:TU_PASSWORD@postgres:5432/featmap?sslmode=disable",
  "jwtSecret": "GENERA_UNA_CADENA_ALEATORIA_SEGURA_AQUI",
  "port": "5000",
  "emailFrom": "tu-email@ejemplo.com",
  "smtpServer": "smtp.tu-servidor.com",
  "smtpPort": "587",
  "smtpUser": "tu-usuario-smtp",
  "smtpPass": "tu-password-smtp"
}
```

**Importante:**
- Cambia `appSiteURL` a la URL de tu servidor (puedes usar el IP o un dominio si lo tienes)
- Genera un `jwtSecret` seguro (puedes usar: `openssl rand -base64 32`)
- Ajusta la cadena de conexión de la base de datos según tus valores del `.env`
- Si no usas HTTPS, mantén `"environment": "development"`, si usas HTTPS, elimina esa línea

## Paso 7: Crear Directorio para Datos de PostgreSQL

```bash
# Crear directorio para persistir los datos de PostgreSQL
mkdir -p /opt/featmap/data
chmod 755 /opt/featmap/data
```

## Paso 8: Construir y Levantar los Servicios

```bash
cd /opt/featmap

# Construir las imágenes
docker-compose build

# Levantar los servicios en segundo plano
docker-compose up -d

# Ver los logs para verificar que todo esté funcionando
docker-compose logs -f
```

## Paso 9: Verificar que los Servicios Estén Corriendo

```bash
# Ver el estado de los contenedores
docker-compose ps

# Verificar que PostgreSQL esté saludable
docker-compose exec postgres pg_isready -U featmap_user

# Ver los logs de la aplicación
docker-compose logs featmap
```

## Paso 10: Configurar el Firewall (si es necesario)

Si tu droplet tiene un firewall activo, necesitas abrir el puerto:

```bash
# Para UFW (si está instalado)
ufw allow 5000/tcp

# Para iptables directamente
iptables -A INPUT -p tcp --dport 5000 -j ACCEPT
```

## Paso 11: Acceder a la Aplicación

Abre tu navegador y visita:
```
http://68.183.175.19:5000
```

## Comandos Útiles

### Ver logs en tiempo real
```bash
docker-compose logs -f
```

### Detener los servicios
```bash
docker-compose down
```

### Reiniciar los servicios
```bash
docker-compose restart
```

### Actualizar la aplicación
```bash
cd /opt/featmap
git pull  # Si usas git
docker-compose build
docker-compose up -d
```

### Hacer backup de la base de datos
```bash
docker-compose exec postgres pg_dump -U featmap_user featmap > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restaurar backup
```bash
docker-compose exec -T postgres psql -U featmap_user featmap < backup_YYYYMMDD_HHMMSS.sql
```

## Solución de Problemas

### Si PostgreSQL no inicia
```bash
# Verificar logs
docker-compose logs postgres

# Verificar permisos del directorio data
ls -la /opt/featmap/data
```

### Si la aplicación no se conecta a la base de datos
- Verifica que la cadena de conexión en `conf.json` coincida con las variables en `.env`
- Verifica que el servicio `postgres` esté saludable: `docker-compose ps`

### Si el puerto está en uso
```bash
# Ver qué proceso usa el puerto 5000
lsof -i :5000
# O cambiar el puerto en .env y conf.json
```

## Configuración con Dominio y HTTPS (Opcional)

Si quieres usar un dominio y HTTPS, necesitarás:
1. Configurar un proxy reverso con Nginx
2. Configurar SSL con Let's Encrypt
3. Actualizar `appSiteURL` en `conf.json` con tu dominio

¿Necesitas ayuda con la configuración de HTTPS? Puedo ayudarte con eso también.

