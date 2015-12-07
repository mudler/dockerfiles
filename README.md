# Observium

	NAME="observium"
	DIR="/somewhere/observium"
	docker run -d -m 1g \
	    -v $DIR/mysql:/var/lib/mysql \
	    -e DB_USER=$NAME \
	    --restart=always \
	    -e DB_PASS=CHANGEMYPASS \
	    -e DB_NAME=$NAME \
	    --name $NAME-db \
	    sameersbn/mysql:latest

	docker run -d \
	    -v $DIR/data:/data \
	    --restart=always \
	    -e VIRTUAL_HOST=SOMEWHERE.IN.THE.INTERNET \
	    -e TZ="Europe/Vienna" \
	    --link $NAME-db:mysql \
	    -e POLLER=24 \
	    -p 514:514/tcp \
	    --name $NAME \
	    observium/latest

