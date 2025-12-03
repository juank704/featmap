#!/bin/bash

# Script de despliegue para Featmap en Digital Ocean
# Uso: ./deploy.sh root@68.183.175.19

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar que se proporcionó el host
if [ -z "$1" ]; then
    echo -e "${RED}Error: Debes proporcionar el host SSH${NC}"
    echo "Uso: ./deploy.sh usuario@68.183.175.19"
    exit 1
fi

HOST=$1
REMOTE_DIR="/opt/featmap"

echo -e "${GREEN}🚀 Iniciando despliegue de Featmap en ${HOST}${NC}"

# Verificar que docker-compose.yml existe
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml no encontrado${NC}"
    exit 1
fi

# Verificar que .env existe
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  Archivo .env no encontrado. Creando desde .env.example...${NC}"
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${YELLOW}⚠️  Por favor, edita el archivo .env con tus valores antes de continuar${NC}"
        exit 1
    else
        echo -e "${RED}Error: .env.example no encontrado${NC}"
        exit 1
    fi
fi

# Verificar que conf.json existe
if [ ! -f "config/conf.json" ]; then
    echo -e "${RED}Error: config/conf.json no encontrado${NC}"
    exit 1
fi

echo -e "${GREEN}📦 Subiendo archivos al servidor...${NC}"

# Crear directorio remoto si no existe
ssh $HOST "mkdir -p $REMOTE_DIR"

# Subir archivos (excluyendo data, .git, node_modules, etc.)
rsync -avz --progress \
    --exclude 'data' \
    --exclude '.git' \
    --exclude 'node_modules' \
    --exclude 'webapp/node_modules' \
    --exclude '.env' \
    --exclude '*.log' \
    . $HOST:$REMOTE_DIR/

echo -e "${GREEN}📝 Subiendo archivo .env...${NC}"
scp .env $HOST:$REMOTE_DIR/.env

echo -e "${GREEN}🔧 Configurando en el servidor...${NC}"

# Ejecutar comandos en el servidor remoto
ssh $HOST << EOF
    set -e
    cd $REMOTE_DIR
    
    # Crear directorio para datos de PostgreSQL si no existe
    mkdir -p data
    chmod 755 data
    
    # Verificar que Docker esté instalado
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}⚠️  Docker no está instalado. Instalando...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
    fi
    
    # Verificar que Docker Compose esté instalado
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}⚠️  Docker Compose no está instalado. Instalando...${NC}"
        apt-get update
        apt-get install -y docker-compose
    fi
    
    # Construir las imágenes
    echo -e "${GREEN}🔨 Construyendo imágenes Docker...${NC}"
    docker-compose build
    
    # Detener contenedores existentes si los hay
    echo -e "${GREEN}🛑 Deteniendo contenedores existentes...${NC}"
    docker-compose down || true
    
    # Levantar los servicios
    echo -e "${GREEN}🚀 Iniciando servicios...${NC}"
    docker-compose up -d
    
    # Esperar un momento para que los servicios inicien
    sleep 5
    
    # Verificar estado
    echo -e "${GREEN}✅ Verificando estado de los servicios...${NC}"
    docker-compose ps
    
    echo -e "${GREEN}📋 Últimas líneas de logs:${NC}"
    docker-compose logs --tail=20
EOF

echo -e "${GREEN}✅ Despliegue completado!${NC}"
echo -e "${GREEN}🌐 Accede a la aplicación en: http://${HOST#*@}:5000${NC}"
echo ""
echo -e "${YELLOW}💡 Comandos útiles:${NC}"
echo "  Ver logs: ssh $HOST 'cd $REMOTE_DIR && docker-compose logs -f'"
echo "  Reiniciar: ssh $HOST 'cd $REMOTE_DIR && docker-compose restart'"
echo "  Estado: ssh $HOST 'cd $REMOTE_DIR && docker-compose ps'"

