#!/bin/bash

# Web3 Whitelist Landing Page - VPS Setup Script
# Supports Ubuntu 20.04+ (DigitalOcean, AWS EC2, Linode)

set -e

echo "🚀 Starting Web3 Whitelist Landing Page setup..."

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Node.js 18 LTS
echo "📦 Installing Node.js 18 LTS..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 globally
echo "📦 Installing PM2..."
sudo npm install -g pm2

# Install Nginx
echo "📦 Installing Nginx..."
sudo apt-get install -y nginx

# Install certbot for SSL (optional)
echo "📦 Installing Certbot for SSL..."
sudo apt-get install -y certbot python3-certbot-nginx

# Clone repository (replace with your actual repo URL)
echo "📂 Cloning repository..."
REPO_URL=${1:-"https://github.com/your-username/web3-whitelist.git"}
APP_DIR="/var/www/web3-whitelist"

if [ -d "$APP_DIR" ]; then
    echo "Directory exists, pulling latest changes..."
    cd $APP_DIR
    git pull
else
    sudo git clone $REPO_URL $APP_DIR
fi

cd $APP_DIR

# Set proper permissions
sudo chown -R $USER:$USER $APP_DIR

# Install dependencies
echo "📦 Installing application dependencies..."
npm install

# Build application
echo "🔨 Building application..."
npm run build

# Configure Nginx
echo "🔧 Configuring Nginx..."
sudo tee /etc/nginx/sites-available/web3-whitelist > /dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN:-localhost};

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Serve static files from dist/public
    location / {
        root $APP_DIR/dist/public;
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # Proxy API requests to Node.js app
    location /api/ {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/web3-whitelist /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Start and enable Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx

# Create environment file
echo "⚙️ Creating environment configuration..."
tee $APP_DIR/.env > /dev/null <<EOF
NODE_ENV=production
PORT=3001
APP_URL=${APP_URL:-http://localhost}
EOF

# Start application with PM2
echo "🚀 Starting application with PM2..."
cd $APP_DIR
pm2 delete web3-whitelist 2>/dev/null || true
pm2 start npm --name "web3-whitelist" -- start
pm2 save
pm2 startup

# Configure firewall
echo "🔒 Configuring firewall..."
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# Display status
echo "✅ Setup completed successfully!"
echo ""
echo "📊 Application Status:"
pm2 status

echo ""
echo "🌐 Your Web3 Whitelist is now running!"
echo "🔗 URL: http://$(curl -s ifconfig.me || echo 'your-server-ip')"
echo ""
echo "📋 Next steps:"
echo "1. Point your domain to this server's IP address"
echo "2. Run: sudo certbot --nginx -d yourdomain.com (for SSL)"
echo "3. Update APP_URL in .env file with your domain"
echo "4. Restart with: pm2 restart web3-whitelist"
echo ""
echo "📚 Useful commands:"
echo "  pm2 status          - Check application status"
echo "  pm2 logs            - View application logs"
echo "  pm2 restart web3-whitelist - Restart application"
echo "  sudo nginx -t       - Test Nginx configuration"
echo "  sudo systemctl status nginx - Check Nginx status"
