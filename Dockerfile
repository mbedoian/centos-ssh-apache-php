# =============================================================================
# jdeathe/centos-ssh-apache-php
#
# CentOS-6, Apache 2.2, PHP 5.3, PHP memcached 1.0, PHP APC 3.1, Composer
# 
# =============================================================================
FROM jdeathe/centos-ssh:centos-6

MAINTAINER James Deathe <james.deathe@gmail.com>

# -----------------------------------------------------------------------------
# Add a "Message of the Day" to help identify container if logging in via SSH
# -----------------------------------------------------------------------------
RUN echo '[ CentOS-6 / Apache / PHP (Standard) ]' > /etc/motd

# -----------------------------------------------------------------------------
# Base Apache, PHP
# -----------------------------------------------------------------------------
RUN yum --setopt=tsflags=nodocs -y install \
	elinks \
	httpd \
	mod_ssl \
	php \
	php-cli \
	php-pecl-apc \
	php-pecl-memcached \
	&& rm -rf /var/cache/yum/* \
	&& yum clean all

# Display the contents of the new certificate for reference
RUN openssl x509 -in /etc/pki/tls/certs/localhost.crt -text

# -----------------------------------------------------------------------------
# Global Apache configuration changes
# -----------------------------------------------------------------------------
RUN sed -i \
	-e 's~^ServerSignature On$~ServerSignature Off~g' \
	-e 's~^ServerTokens OS$~ServerTokens Prod~g' \
	-e 's~^#ExtendedStatus On$~ExtendedStatus On~g' \
	-e 's~^DirectoryIndex \(.*\)$~DirectoryIndex \1 index.php~g' \
	-e 's~^NameVirtualHost \(.*\)$~#NameVirtualHost \1~g' \
	/etc/httpd/conf/httpd.conf

# -----------------------------------------------------------------------------
# Disable Apache directory indexes
# -----------------------------------------------------------------------------
RUN sed -i \
	-e 's~^IndexOptions \(.*\)$~#IndexOptions \1~g' \
	-e 's~^IndexIgnore \(.*\)$~#IndexIgnore \1~g' \
	-e 's~^AddIconByEncoding \(.*\)$~#AddIconByEncoding \1~g' \
	-e 's~^AddIconByType \(.*\)$~#AddIconByType \1~g' \
	-e 's~^AddIcon \(.*\)$~#AddIcon \1~g' \
	-e 's~^DefaultIcon \(.*\)$~#DefaultIcon \1~g' \
	-e 's~^ReadmeName \(.*\)$~#ReadmeName \1~g' \
	-e 's~^HeaderName \(.*\)$~#HeaderName \1~g' \
	/etc/httpd/conf/httpd.conf

# -----------------------------------------------------------------------------
# Disable Apache language based content negotiation
# -----------------------------------------------------------------------------
RUN sed -i \
	-e 's~^LanguagePriority \(.*\)$~#LanguagePriority \1~g' \
	-e 's~^ForceLanguagePriority \(.*\)$~#ForceLanguagePriority \1~g' \
	-e 's~^AddLanguage \(.*\)$~#AddLanguage \1~g' \
	/etc/httpd/conf/httpd.conf

# -----------------------------------------------------------------------------
# Disable all Apache modules and enable the minimum
# -----------------------------------------------------------------------------
RUN sed -i \
	-e 's~^\(LoadModule .*\)$~#\1~g' \
	-e 's~^#LoadModule mime_module ~LoadModule mime_module ~g' \
	-e 's~^#LoadModule log_config_module ~LoadModule log_config_module ~g' \
	-e 's~^#LoadModule setenvif_module ~LoadModule setenvif_module ~g' \
	-e 's~^#LoadModule status_module ~LoadModule status_module ~g' \
	-e 's~^#LoadModule authz_host_module ~LoadModule authz_host_module ~g' \
	-e 's~^#LoadModule dir_module ~LoadModule dir_module ~g' \
	-e 's~^#LoadModule alias_module ~LoadModule alias_module ~g' \
	-e 's~^#LoadModule expires_module ~LoadModule expires_module ~g' \
	-e 's~^#LoadModule deflate_module ~LoadModule deflate_module ~g' \
	-e 's~^#LoadModule headers_module ~LoadModule headers_module ~g' \
	-e 's~^#LoadModule alias_module ~LoadModule alias_module ~g' \
	/etc/httpd/conf/httpd.conf

# -----------------------------------------------------------------------------
# Custom Apache configuration
# -----------------------------------------------------------------------------
RUN echo $'\n#\n# Custom configuration\n#' >> /etc/httpd/conf/httpd.conf
RUN echo 'Options -Indexes' >> /etc/httpd/conf/httpd.conf
RUN echo 'Listen 8443' >> /etc/httpd/conf/httpd.conf
RUN echo 'NameVirtualHost *:80' >> /etc/httpd/conf/httpd.conf
RUN echo 'NameVirtualHost *:8443' >> /etc/httpd/conf/httpd.conf
RUN echo '#NameVirtualHost *:443' >> /etc/httpd/conf/httpd.conf
RUN echo 'Include /var/www/app/vhost.conf' >> /etc/httpd/conf/httpd.conf
RUN echo '#Include /var/www/app/vhost-ssl.conf' >> /etc/httpd/conf/httpd.conf
RUN echo $'\n<Location /server-status>' >> /etc/httpd/conf/httpd.conf
RUN echo '    SetHandler server-status' >> /etc/httpd/conf/httpd.conf
RUN echo '    Order deny,allow' >> /etc/httpd/conf/httpd.conf
RUN echo '    Deny from all' >> /etc/httpd/conf/httpd.conf
RUN echo '    Allow from localhost 127.0.0.1' >> /etc/httpd/conf/httpd.conf
RUN echo '</Location>' >> /etc/httpd/conf/httpd.conf

# -----------------------------------------------------------------------------
# Limit process for the application user
# -----------------------------------------------------------------------------
RUN echo $'\napache\tsoft\tnproc\t30\napache\thard\tnproc\t50' >> /etc/security/limits.conf
RUN echo $'\napp-www\tsoft\tnproc\t30\napp-www\thard\tnproc\t50' >> /etc/security/limits.conf

# -----------------------------------------------------------------------------
# Disable the default SSL Virtual Host
# 	Simplest approach is to use non-standard port instead of attempting to 
# 	comment out or remove the necessary lines
# -----------------------------------------------------------------------------
RUN sed -i \
	-e 's~^<VirtualHost _default_:443>$~<VirtualHost _default_:404>~g' \
	/etc/httpd/conf.d/ssl.conf

# -----------------------------------------------------------------------------
# Disable the SSL support by default
# -----------------------------------------------------------------------------
RUN mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.off
RUN touch /etc/httpd/conf.d/ssl.conf
RUN chmod 444 /etc/httpd/conf.d/ssl.conf

# -----------------------------------------------------------------------------
# Global PHP configuration changes
# -----------------------------------------------------------------------------
RUN sed -i \
	-e 's~^;date.timezone =$~date.timezone = UTC~g' \
	-e 's~^;user_ini.filename =$~user_ini.filename =~g' \
	/etc/php.ini

# -----------------------------------------------------------------------------
# APC op-code cache stats
#	Note there will be 1 cache per process if using mod_fcgid
# -----------------------------------------------------------------------------
RUN sed -i \
	-e "s~'ADMIN_PASSWORD','password'~'ADMIN_PASSWORD','apc!123'~g" \
	-e "s~'DATE_FORMAT', 'Y/m/d H:i:s'~'DATE_FORMAT', 'Y-m-d H:i:s'~g" \
	-e "s~php_uname('n');~gethostname();~g" \
	/usr/share/php-pecl-apc/apc.php

# -----------------------------------------------------------------------------
# Add default service users
# -----------------------------------------------------------------------------
RUN useradd -u 501 -d /var/www/app -m app
RUN useradd -u 502 -d /var/www/app -M -s /sbin/nologin -G app app-www
RUN usermod -a -G app-www app
RUN usermod -a -G app-www apache

# -----------------------------------------------------------------------------
# Add a symbolic link to the app users home within the home directory
# -----------------------------------------------------------------------------
RUN ln -s /var/www/app /home/app

# -----------------------------------------------------------------------------
# Create the initial directory structure
# -----------------------------------------------------------------------------
RUN mkdir -p /var/www/app/{public_html,src,var/{log,session,tmp}}

# -----------------------------------------------------------------------------
# Populate the app home directory
# -----------------------------------------------------------------------------
ADD var/www/app/vhost.conf /var/www/app/vhost.conf
ADD var/www/app/vhost.conf /var/www/app/vhost-ssl.conf
ADD var/www/app/public_html/index.php /var/www/app/public_html/index.php

# Add PHP Info _phpinfo.php
RUN echo '<?php phpinfo(); ?>' > /var/www/app/public_html/_phpinfo.php

# Add APC Control Panel _apc.php
RUN cp /usr/share/php-pecl-apc/apc.php /var/www/app/public_html/_apc.php

# -----------------------------------------------------------------------------
# Create the SSL VirtualHosts configuration file
# -----------------------------------------------------------------------------
RUN sed -i \
	-e 's~^<VirtualHost \*:80 \*:8443>$~#<VirtualHost \*:80 \*:8443>~g' \
	-e 's~^#<VirtualHost \*:443>$~<VirtualHost \*:443>~g' \
	-e 's~#SSLEngine \(.*\)$~SSLEngine \1~g' \
	-e 's~#SSLOptions \(.*\)$~SSLOptions \1~g' \
	-e 's~#SSLProtocol \(.*\)$~SSLProtocol \1~g' \
	-e 's~#SSLCipherSuite \(.*\)$~SSLCipherSuite \1~g' \
	-e 's~#SSLCertificateFile \(.*\)$~SSLCertificateFile \1~g' \
	-e 's~#SSLCertificateKeyFile \(.*\)$~SSLCertificateKeyFile \1~g' \
	/var/www/app/vhost-ssl.conf

# -----------------------------------------------------------------------------
# Set permissions (app:app-www === 501:502)
# -----------------------------------------------------------------------------
RUN chown -R 501:502 /var/www/app
RUN chmod 775 /var/www/app

# -----------------------------------------------------------------------------
# Create the template directory
# -----------------------------------------------------------------------------
RUN cp -rpf /var/www/app /var/www/.app-skel

# -----------------------------------------------------------------------------
# Copy files into place
# -----------------------------------------------------------------------------
ADD etc/services-config/supervisor/supervisord.conf /etc/services-config/supervisor/
RUN ln -sf /etc/services-config/supervisor/supervisord.conf /etc/supervisord.conf

RUN mkdir -p /etc/services-config/{httpd/{conf,conf.d},ssl/{certs,private}}

RUN ln -sf /etc/services-config/ssl/certs/localhost.crt /etc/pki/tls/certs/localhost.crt
RUN ln -sf /etc/services-config/ssl/private/localhost.key /etc/pki/tls/private/localhost.key

ADD etc/services-config/httpd/apache-bootstrap.conf /etc/services-config/httpd/
RUN ln -sf /etc/services-config/httpd/apache-bootstrap.conf /etc/apache-bootstrap.conf

RUN cp /etc/httpd/conf/httpd.conf /etc/services-config/httpd/conf/
RUN ln -sf /etc/services-config/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf

ADD etc/apache-bootstrap /etc/
RUN chmod +x /etc/apache-bootstrap

# -----------------------------------------------------------------------------
# Set default environment variables used to identify the service container
# -----------------------------------------------------------------------------
ENV APACHE_SERVER_NAME app-1.local
ENV APACHE_SERVER_ALIAS app-1
ENV SERVICE_UNIT_APP_GROUP app-1
ENV SERVICE_UNIT_LOCAL_ID 1
ENV SERVICE_UNIT_INSTANCE 1
ENV DATE_TIMEZONE UTC

EXPOSE 80 8443 443

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]