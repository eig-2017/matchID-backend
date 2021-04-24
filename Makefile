##############################################
# WARNING : THIS FILE SHOULDN'T BE TOUCHED   #
#    FOR ENVIRONNEMENT CONFIGURATION         #
# CONFIGURABLE VARIABLES SHOULD BE OVERRIDED #
# IN THE 'artifacts' FILE, AS NOT COMMITTED  #
##############################################

SHELL=/bin/bash
OS_TYPE := $(shell cat /etc/os-release | grep -E '^NAME=' | sed 's/^.*debian.*$$/DEB/I;s/^.*ubuntu.*$$/DEB/I;s/^.*fedora.*$$/RPM/I;s/.*centos.*$$/RPM/I;')

export APP_DNS=tuto.matchid.io

export DEBIAN_FRONTEND=noninteractive
export USE_TTY := $(shell test -t 1 && USE_TTY="-t")
#matchID default exposition port
export APP_GROUP=matchID
export APP=backend
export APP_PATH=$(shell pwd)
export API_PATH=${APP_GROUP}/api/v0
export API_TEST_PATH=${API_PATH}/swagger.json
export API_TEST_JSON_PATH=swagger
export PORT=8081
export BACKEND_PORT=8081
export TIMEOUT=30
# auth method - do not use auth by default (auth can be both passwords and OAuth)
export NO_AUTH=True
export TWITTER_OAUTH_ID=None
export TWITTER_OAUTH_SECRET=None
export FACEBOOK_OAUTH_ID=None
export FACEBOOK_OAUTH_SECRET=None
export GITHUB_OAUTH_ID=fd8e86cc09d3f9607e16
export GITHUB_OAUTH_SECRET=203010f81158d3ceab0297a213e80bc0fbfe7f8e

#matchID default paths
export BACKEND := $(shell pwd)
export UPLOAD=${BACKEND}/upload
export PROJECTS=${BACKEND}/projects
export EXAMPLES=${BACKEND}/../examples
export TUTORIAL=${BACKEND}/../tutorial
export MODELS=${BACKEND}/models
export LOG=${BACKEND}/log
export COMPOSE_HTTP_TIMEOUT=120
export DOCKER_USERNAME=$(shell echo ${APP_GROUP} | tr '[:upper:]' '[:lower:]')
export DC_DIR=${BACKEND}/docker-components
export DC_FILE=${DC_DIR}/docker-compose
export DC_PREFIX := $(shell echo ${APP_GROUP} | tr '[:upper:]' '[:lower:]')
export DC_IMAGE_NAME=${DC_PREFIX}-${APP}
export DC_NETWORK=${DC_PREFIX}
export DC_NETWORK_OPT=
export DC_BUILD_ARGS = --pull --no-cache
export GIT_ROOT=https://github.com/matchid-project
export GIT_ORIGIN=origin
export GIT_BRANCH := $(shell [ -f "/usr/bin/git" ] && git branch | grep '*' | awk '{print $$2}')
export GIT_BRANCH_MASTER=master
export GIT_TOOLS=tools
export GIT_FRONTEND=frontend
export GIT_FRONTEND_BRANCH:=$(shell [ "${GIT_BRANCH}" = "${GIT_BRANCH_MASTER}" ] && echo -n "${GIT_BRANCH_MASTER}" || echo -n dev)

export FRONTEND=${BACKEND}/../${GIT_FRONTEND}
export FRONTEND_DC_IMAGE_NAME=${DC_PREFIX}-${GIT_FRONTEND}

export API_SECRET_KEY:=$(shell openssl rand -base64 24)
export ADMIN_PASSWORD:=$(shell openssl rand -base64 24)
export ADMIN_PASSWORD_HASH:=$(shell echo -n ${ADMIN_PASSWORD} | sha384sum | sed 's/\s*\-.*//')
export POSTGRES_PASSWORD=matchid


# backup dir
export BACKUP_DIR=${BACKEND}/backup

# s3 conf
# s3 conf has to be stored in two ways :
# classic way (.aws/config and .aws/credentials) for s3 backups
# to use within matchid backend, you have to add credential as env variables and declare configuration in a s3 connector
# 	export aws_access_key_id=XXXXXXXXXXXXXXXXX
# 	export aws_secret_access_key=XXXXXXXXXXXXXXXXXXXXXXXXXXX
export MATCHID_DATA_BUCKET=$(shell echo ${APP_GROUP} | tr '[:upper:]' '[:lower:]')
export MATCHID_CONFIG_BUCKET=$(shell echo ${APP_GROUP} | tr '[:upper:]' '[:lower:]')

# elasticsearch defaut configuration
export ES_NODES = 1		# elasticsearch number of nodes
export ES_SWARM_NODE_NUMBER = 2		# elasticsearch number of nodes
export ES_MEM = 1024m		# elasticsearch : memory of each node
export ES_VERSION = 7.10.1
export ES_DATA = ${BACKEND}/esdata
export ES_THREADS = 2
export ES_MAX_TRIES = 3
export ES_CHUNK = 500
export ES_BACKUP_FILE := $(shell echo esdata_`date +"%Y%m%d"`.tar)
export ES_BACKUP_FILE_SNAR = esdata.snar

export DB_SERVICES=elasticsearch postgres

export SERVICES=${DB_SERVICES} backend frontend

dummy		    := $(shell touch artifacts)
include ./artifacts

tag                 := $(shell [ -f "/usr/bin/git" ] && git describe --tags | sed 's/-.*//')
version 			:= $(shell export LC_COLLATE=C;export LC_ALL=C;cat tagfiles.version | xargs -I '{}' find {} -type f | egrep -v 'conf/security/(github|facebook|twitter).yml$$|.tar.gz$$|.pyc$$|.gitignore$$' | sort | xargs cat | sha1sum - | sed 's/\(......\).*/\1/')
export APP_VERSION =  ${tag}-${version}

commit 				= ${APP_VERSION}
lastcommit          := $(shell touch .lastcommit && cat .lastcommit)
date                := $(shell date -I)
id                  := $(shell openssl rand -base64 8)

vm_max_count		:= $(shell cat /etc/sysctl.conf | egrep vm.max_map_count\s*=\s*262144 && echo true)

PG := 'postgres'
DC := 'docker-compose'
include /etc/os-release


test:
	echo "${DC_LOCAL}" | base64 -d > docker-compose-local.yml;\
	echo "${OAUTH_CREDS_ENC}" | base64 -d | gpg -d --passphrase ${SSHPWD} --batch > creds-local.yml

version: frontend-version
	@echo ${APP_GROUP} ${APP} ${APP_VERSION}

frontend-version:
	@if [ -d "${FRONTEND}" ];then\
		cd ${FRONTEND} && make -s version;\
	fi


version-files:
	@export LC_COLLATE=C;export LC_ALL=C;cat tagfiles.version | xargs -I '{}' find {} -type f | egrep -v 'conf/security/(github|facebook|twitter).yml$$|.tar.gz$$|.pyc$$|.gitignore$$' | sort

config:
	@if [ ! -f "/usr/bin/git" ];then\
		if [ "${OS_TYPE}" = "DEB" ]; then\
			sudo apt-get install git -yq;\
		fi;\
		if [ "${OS_TYPE}" = "RPM" ]; then\
			sudo yum install -y git;\
		fi;\
	fi
	@if [ -z "${TOOLS_PATH}" ];then\
		if [ ! -f "${APP_PATH}/${GIT_TOOLS}" ]; then\
			git clone -q ${GIT_ROOT}/${GIT_TOOLS};\
		fi;\
		make -C ${APP_PATH}/${GIT_TOOLS} config ${MAKEOVERRIDES};\
	else\
		ln -s ${TOOLS_PATH} ${APP_PATH}/${GIT_TOOLS};\
	fi
	cp artifacts ${APP_PATH}/${GIT_TOOLS}/
	@touch config

config-clean:
	@rm -rf tools config

docker-clean: stop
	docker container rm matchid-build-front matchid-nginx elasticsearch postgres kibana

clean: frontend-clean config-clean

network-stop:
	docker network rm ${DC_NETWORK}

network: config
	@docker network create ${DC_NETWORK_OPT} ${DC_NETWORK} 2> /dev/null; true

elasticsearch-dev-stop: elasticsearch-stop

elasticsearch-docker-check:
	@if [ ! -f ".docker.elastic.co-elasticsearch-oss:${ES_VERSION}" ]; then\
			(\
					(docker image inspect docker.elastic.co/elasticsearch/elasticsearch-oss:${ES_VERSION} > /dev/null 2>&1)\
					&& touch .docker.elastic.co-elasticsearch-oss:${ES_VERSION}\
			)\
			||\
			(\
					(docker pull docker.elastic.co/elasticsearch/elasticsearch-oss:${ES_VERSION} 2> /dev/null)\
					&& touch .docker.elastic.co-elasticsearch-oss:${ES_VERSION}\
			)\
			|| (echo no image found for docker.elastic.co/elasticsearch/elasticsearch-oss:${ES_VERSION} && exit 1);\
	fi;

elasticsearch-stop:
	@echo docker-compose down matchID elasticsearch
ifeq "$(ES_NODES)" "1"
	@${DC} -f ${DC_FILE}-elasticsearch-phonetic.yml down
else
	@${DC} -f ${DC_FILE}-elasticsearch-huge.yml down
endif

elasticsearch2-stop:
	@${DC} -f ${DC_FILE}-elasticsearch-huge-remote.yml down

elasticsearch-backup: elasticsearch-stop backup-dir
	@echo taring ${ES_DATA} to ${BACKUP_DIR}/${ES_BACKUP_FILE}
	@cd $$(dirname ${ES_DATA}) && sudo tar --create --file=${BACKUP_DIR}/${ES_BACKUP_FILE} --listed-incremental=${BACKUP_DIR}/${ES_BACKUP_FILE_SNAR} $$(basename ${ES_DATA})

elasticsearch-restore: elasticsearch-stop backup-dir
	@if [ -d "$(ES_DATA)" ] ; then (echo purgin ${ES_DATA} && sudo rm -rf ${ES_DATA} && echo purge done) ; fi
	@if [ ! -f "${BACKUP_DIR}/${ES_BACKUP_FILE}" ] ; then (echo no such archive "${BACKUP_DIR}/${ES_BACKUP_FILE}" && exit 1);fi
	@echo restoring from ${BACKUP_DIR}/${ES_BACKUP_FILE} to ${ES_DATA} && \
	 cd $$(dirname ${ES_DATA}) && \
	 sudo tar --extract --listed-incremental=/dev/null --file ${BACKUP_DIR}/${ES_BACKUP_FILE} && \
	 echo backup restored

elasticsearch-storage-push:
	@if [ ! -f "${BACKUP_DIR}/${ES_BACKUP_FILE}" ] ; then (echo no archive to push: "${BACKUP_DIR}/${ES_BACKUP_FILE}" && exit 1);fi
	@make -C ${APP_PATH}/${GIT_TOOLS} storage-push\
		FILE=${BACKUP_DIR}/${ES_BACKUP_FILE}\
		STORAGE_BUCKET=${STORAGE_BUCKET} STORAGE_ACCESS_KEY=${STORAGE_ACCESS_KEY} STORAGE_SECRET_KEY=${STORAGE_SECRET_KEY}
	@make -C ${APP_PATH}/${GIT_TOOLS} storage-push\
		FILE=${BACKUP_DIR}/${ES_BACKUP_FILE_SNAR}\
		STORAGE_BUCKET=${STORAGE_BUCKET} STORAGE_ACCESS_KEY=${STORAGE_ACCESS_KEY} STORAGE_SECRET_KEY=${STORAGE_SECRET_KEY}

elasticsearch-storage-pull: backup-dir
	@echo pulling ${BUCKET}/${ES_BACKUP_FILE}
	@make -C ${APP_PATH}/${GIT_TOOLS} storage-pull\
		FILE=${ES_BACKUP_FILE} DATA_DIR=${BACKUP_DIR}\
		STORAGE_BUCKET=${STORAGE_BUCKET} STORAGE_ACCESS_KEY=${STORAGE_ACCESS_KEY} STORAGE_SECRET_KEY=${STORAGE_SECRET_KEY}

backup-dir:
	@if [ ! -d "$(BACKUP_DIR)" ] ; then mkdir -p $(BACKUP_DIR) ; fi

vm_max:
ifeq ("$(vm_max_count)", "")
	@echo updating vm.max_map_count $(vm_max_count) to 262144
	sudo sysctl -w vm.max_map_count=262144
endif

elasticsearch-dev: elasticsearch

elasticsearch: network vm_max
	@echo docker-compose up matchID elasticsearch with ${ES_NODES} nodes
	@cat ${DC_FILE}-elasticsearch.yml | sed "s/%M/${ES_MEM}/g" > ${DC_FILE}-elasticsearch-huge.yml
	@(if [ ! -d ${ES_DATA}/node1 ]; then sudo mkdir -p ${ES_DATA}/node1 ; sudo chmod g+rw ${ES_DATA}/node1/.; sudo chown 1000:1000 ${ES_DATA}/node1/.; fi)
	@(i=$(ES_NODES); while [ $${i} -gt 1 ]; \
		do \
			if [ ! -d ${ES_DATA}/node$$i ]; then (echo ${ES_DATA}/node$$i && sudo mkdir -p ${ES_DATA}/node$$i && sudo chmod g+rw ${ES_DATA}/node$$i/. && sudo chown 1000:1000 ${ES_DATA}/node$$i/.); fi; \
		cat ${DC_FILE}-elasticsearch-node.yml | sed "s/%N/$$i/g;s/%MM/${ES_MEM}/g;s/%M/${ES_MEM}/g" >> ${DC_FILE}-elasticsearch-huge.yml; \
		i=`expr $$i - 1`; \
	done;\
	true)
	${DC} -f ${DC_FILE}-elasticsearch-huge.yml up -d
	@timeout=${TIMEOUT} ; ret=1 ; until [ "$$timeout" -le 0 -o "$$ret" -eq "0"  ] ; do (docker exec -i ${USE_TTY} ${DC_PREFIX}-elasticsearch curl -s --fail -XGET localhost:9200/_cat/indices > /dev/null) ; ret=$$? ; if [ "$$ret" -ne "0" ] ; then echo -en "\rwaiting for elasticsearch to start $$timeout" ; fi ; ((timeout--)); sleep 1 ; done ; echo ; exit $$ret

elasticsearch2:
	@echo docker-compose up matchID elasticsearch with ${ES_NODES} nodes
	@cat ${DC_FILE}-elasticsearch.yml | head -8 > ${DC_FILE}-elasticsearch-huge-remote.yml
	@(i=$$(( $(ES_NODES) * $(ES_SWARM_NODE_NUMBER) ));j=$$(( $(ES_NODES) * $(ES_SWARM_NODE_NUMBER) - $(ES_NODES))); while [ $${i} -gt $${j} ]; \
	        do \
	              if [ ! -d ${ES_DATA}/node$$i ]; then (echo ${ES_DATA}/node$$i && sudo mkdir -p ${ES_DATA}/node$$i && sudo chmod g+rw ${ES_DATA}/node$$i/. && sudo chown 1000:1000 ${ES_DATA}/node$$i/.); fi; \
	              cat ${DC_FILE}-elasticsearch-node.yml | sed "s/%N/$$i/g;s/%MM/${ES_MEM}/g;s/%M/${ES_MEM}/g" | egrep -v 'depends_on|- elasticsearch' >> ${DC_FILE}-elasticsearch-huge-remote.yml; \
	              i=`expr $$i - 1`; \
	 	done;\
	true)
	${DC} -f ${DC_FILE}-elasticsearch-huge-remote.yml up -d

kibana-dev-stop: kibana-stop

kibana-dev: kibana

kibana-stop:
	${DC} -f ${DC_FILE}-kibana.yml down
kibana: network
ifeq ("$(wildcard ${BACKEND}/kibana)","")
	sudo mkdir -p ${BACKEND}/kibana && sudo chmod g+rw ${BACKEND}/kibana/. && sudo chown 1000:1000 ${BACKEND}/kibana/.
endif
	${DC} -f ${DC_FILE}-kibana.yml up -d

postgres-docker-check:
	@if [ ! -f ".postgres:latest" ]; then\
		(\
				(docker image inspect postgres:latest > /dev/null 2>&1)\
				&& touch .postgres:latest\
		)\
		||\
		(\
				(docker pull postgres:latest 2> /dev/null)\
				&& touch .postgres:latest\
		)\
		|| (echo no image found for postgres:latest && exit 1);\
	fi;

postgres-dev-stop: postgres-stop

postgres-stop:
	${DC} -f ${DC_FILE}-${PG}.yml down

postgres-dev: postgres

postgres: network
	${DC} -f ${DC_FILE}-${PG}.yml up -d
	@sleep 5 && docker exec ${DC_PREFIX}-postgres psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch"

backend-stop:
	${DC} down

backend-prep:
ifeq ("$(wildcard ${UPLOAD})","")
	@sudo mkdir -p ${UPLOAD}
endif
ifeq ("$(wildcard ${PROJECTS})","")
	@sudo mkdir -p ${PROJECTS}
endif
ifeq ("$(wildcard ${MODELS})","")
	@sudo mkdir -p ${PROJECTS}
endif

backend-dev: network backend-prep
	@echo WARNING new ADMIN_PASSWORD is ${ADMIN_PASSWORD}
	@if [ -f docker-compose-local.yml ];then\
		DC_LOCAL="-f docker-compose-local.yml";\
	fi;\
	export BACKEND_ENV=development;\
	export DC_POSTFIX="-dev";\
	if [ "${commit}" != "${lastcommit}" ];then\
		echo building matchID backend after new commit;\
		${DC} build;\
		echo "${commit}" > ${BACKEND}/.lastcommit;\
	fi;\
	${DC} -f docker-compose.yml -f docker-compose-dev.yml $$DC_LOCAL up -d

backend-dev-stop:
	${DC} -f docker-compose.yml down

backend-check-build:
	@if [ -f docker-compose-local.yml ];then\
		DC_LOCAL="-f docker-compose-local.yml";\
	fi;\
	export BACKEND_ENV=production;\
	if [ "${commit}" != "${lastcommit}" ];then\
		echo building ${APP_GROUP} ${APP} for dev after new commit;\
		${DC} build $$DC_LOCAL;\
		echo "${commit}" > ${BACKEND}/.lastcommit;\
	fi;\
	${DC} -f docker-compose.yml $$DC_LOCAL config -q

backend-docker-pull:
	@(\
		(docker pull ${DOCKER_USERNAME}/${DC_PREFIX}-${APP}:${APP_VERSION} > /dev/null 2>&1)\
		&& echo docker successfully pulled && (echo "${commit}" > ${BACKEND}/.lastcommit) \
	) || echo "${DOCKER_USERNAME}/${DC_PREFIX}-${APP}:${APP_VERSION} not found on Docker Hub build, using local"

backend-build: backend-prep backend-check-build backend-docker-pull
	@if [ -f docker-compose-local.yml ];then\
		DC_LOCAL="-f docker-compose-local.yml";\
	fi;\
	export BACKEND_ENV=production;\
	if [ "${commit}" != "${lastcommit}" ];then\
		echo building ${APP_GROUP} ${APP} after new commit;\
		${DC} build ${DC_BUILD_ARGS};\
		echo "${commit}" > ${BACKEND}/.lastcommit;\
	fi;
	@docker tag ${DOCKER_USERNAME}/${DC_PREFIX}-${APP}:${APP_VERSION} ${DOCKER_USERNAME}/${DC_PREFIX}-${APP}:latest

backend: network backend-docker-check
	@echo WARNING new ADMIN_PASSWORD is ${ADMIN_PASSWORD}
	@if [ -f docker-compose-local.yml ];then\
		DC_LOCAL="-f docker-compose-local.yml";\
	fi;\
	export BACKEND_ENV=production;\
	${DC} -f docker-compose.yml $$DC_LOCAL up -d
	@timeout=${TIMEOUT} ; ret=1 ; until [ "$$timeout" -le 0 -o "$$ret" -eq "0"  ] ; do (docker exec -i ${USE_TTY} ${DC_PREFIX}-backend curl -s --noproxy "*" --fail -XGET localhost:${BACKEND_PORT}/matchID/api/v0/ > /dev/null) ; ret=$$? ; echo;if [ "$$ret" -ne "0" ] ; then echo -en "\rwaiting for backend to start $$timeout" ; fi ; ((timeout--)); sleep 1 ; done ; echo ; exit $$ret

backend-docker-check: config
	@make -C ${APP_PATH}/${GIT_TOOLS} docker-check DC_IMAGE_NAME=${DC_IMAGE_NAME} APP_VERSION=${APP_VERSION} GIT_BRANCH="${GIT_BRANCH}" ${MAKEOVERRIDES}

backend-docker-push:
	@make -C ${APP_PATH}/${GIT_TOOLS} docker-push DC_IMAGE_NAME=${DC_IMAGE_NAME} APP_VERSION=${APP_VERSION} ${MAKEOVERRIDES}

backend-update:
	@cd ${BACKEND}; git pull ${GIT_ORIGIN} "${GIT_BRANCH}"

update: frontend-update backend-update

services-dev:
	@for service in ${SERVICES}; do\
		(make $$service-dev ${MAKEOVERRIDES} || echo starting $$service failed);\
	done

services-dev-stop:
	@for service in ${SERVICES}; do\
		(make $$service-dev-stop ${MAKEOVERRIDES} || echo stopping $$service failed);\
	done

services:
	@for service in ${SERVICES}; do\
		(make $$service ${MAKEOVERRIDES} || echo starting $$service failed);\
	done

services-stop:
	@for service in ${SERVICES}; do\
		(make $$service-stop ${MAKEOVERRIDES} || echo stopping $$service failed);\
	done

dev: network services-dev

dev-stop: services-dev-stop network-stop

frontend-config:
ifeq ("$(wildcard ${FRONTEND})","")
	@echo downloading frontend code
	@git clone -q ${GIT_ROOT}/${GIT_FRONTEND} ${FRONTEND} #2> /dev/null; true
	@cd ${FRONTEND};git checkout "${GIT_FRONTEND_BRANCH}"
endif
ifeq ("$(wildcard ${FRONTEND}/${GIT_TOOLS})","")
	@ln -s ${APP_PATH}/${GIT_TOOLS} ${FRONTEND}/${GIT_TOOLS}
endif


frontend-docker-check: frontend-config
	@make -C ${FRONTEND} frontend-docker-check GIT_BRANCH="${GIT_FRONTEND_BRANCH}"

frontend-clean:
	@if [ -d "${FRONTEND}" ];then\
		make -C ${FRONTEND} frontend-clean GIT_BRANCH="${GIT_FRONTEND_BRANCH}";\
	fi;

frontend-update:
	@cd ${FRONTEND}; git pull ${GIT_ORIGIN} "${GIT_FRONTEND_BRANCH}"

frontend-dev: frontend-config
	@make -C ${FRONTEND} frontend-dev GIT_BRANCH="${GIT_FRONTEND_BRANCH}"

frontend-dev-stop:
	@if [ -d "${FRONTEND}" ];then\
		make -C ${FRONTEND} frontend-dev-stop GIT_BRANCH="${GIT_FRONTEND_BRANCH}";\
	fi

frontend-build: network frontend-config
	@make -C ${FRONTEND} frontend-build GIT_BRANCH="${GIT_FRONTEND_BRANCH}"

frontend-stop:
	@if [ -d "${FRONTEND}" ];then\
		make -C ${FRONTEND} frontend-stop GIT_BRANCH="${GIT_FRONTEND_BRANCH}";\
	fi

frontend: frontend-docker-check
	@make -C ${FRONTEND} frontend GIT_BRANCH="${GIT_FRONTEND_BRANCH}"

stop: services-stop network-stop
	@echo all components stopped

start: network services
	@sleep 2 && docker-compose logs

up: start

down: stop

restart: down up

docker-save-all: config backend-docker-check frontend-docker-check postgres-docker-check elasticsearch-docker-check
	@if [ ! -f "${DC_DIR}/${DC_PREFIX}-${APP}:${APP_VERSION}.tar.gz" ];then\
		echo saving backend docker image;\
		docker save ${DOCKER_USERNAME}/${DC_PREFIX}-${APP}:${APP_VERSION} | gzip > ${DC_DIR}/${DC_PREFIX}-${APP}:${APP_VERSION}.tar.gz;\
	fi
	@if [ ! -f "${DC_DIR}/elasticsearch-oss:${ES_VERSION}.tar.gz" ];then\
		echo saving elasticsearch docker image;\
		docker save docker.elastic.co/elasticsearch/elasticsearch-oss:${ES_VERSION} | gzip > ${DC_DIR}/elasticsearch-oss:${ES_VERSION}.tar.gz;\
	fi
	@if [ ! -f "${DC_DIR}/postgres:latest.tar.gz" ];then\
		echo saving postgres docker image;\
		docker save postgres:latest | gzip > ${DC_DIR}/postgres:latest.tar.gz;\
	fi
	@FRONTEND_APP_VERSION=$$(cd ${FRONTEND} && make -s version | awk '{print $$NF}');\
	if [ ! -f "${DC_DIR}/${FRONTEND_DC_IMAGE_NAME}:$$FRONTEND_APP_VERSION.tar.gz" ];then\
		echo saving frontend docker image;\
		docker save ${DOCKER_USERNAME}/${FRONTEND_DC_IMAGE_NAME}:$$FRONTEND_APP_VERSION | gzip > ${DC_DIR}/${FRONTEND_DC_IMAGE_NAME}:$$FRONTEND_APP_VERSION.tar.gz;\
	fi

package: docker-save-all
	@FRONTEND_APP_VERSION=$$(cd ${FRONTEND} && make -s version | awk '{print $$NF}');\
	PACKAGE=${APP_GROUP}-${APP_VERSION}-$$FRONTEND_APP_VERSION.tar.gz;\
	if [ ! -f "$$PACKAGE" ];then\
		curl -s -O https://downloads.rclone.org/rclone-current-linux-amd64.rpm;\
		curl -s -O https://downloads.rclone.org/rclone-current-linux-amd64.deb;\
		curl -s -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$$(uname -s)-$$(uname -m)" -o docker-compose;\
		cd ${APP_PATH}/..;\
		DC_DIR=`echo ${DC_DIR} | sed "s|${APP_PATH}|$${APP_PATH##*/}|"`;\
		echo $$DD;\
		tar cvzf $${APP_PATH##*/}/$$PACKAGE \
			$${APP_PATH##*/}/rclone-current-linux*\
			$${APP_PATH##*/}/docker-compose\
			`cd ${APP_PATH};git ls-files | sed "s/^/$${APP_PATH##*/}\//"` \
			$${APP_PATH##*/}/.git\
			$$DC_DIR/postgres:latest.tar.gz\
			$$DC_DIR/${FRONTEND_DC_IMAGE_NAME}:$$FRONTEND_APP_VERSION.tar.gz\
			$$DC_DIR/${DC_PREFIX}-${APP}:${APP_VERSION}.tar.gz\
			$$DC_DIR/elasticsearch-oss:${ES_VERSION}.tar.gz\
			`cd ${APP_PATH}/${GIT_TOOLS};git ls-files | sed "s/^/$${APP_PATH##*/}\/${GIT_TOOLS}\//"`\
			$${APP_PATH##*/}/${GIT_TOOLS}/.git\
			`cd ${FRONTEND};git ls-files | sed "s/^/$${FRONTEND##*/}\//"`\
			$${FRONTEND##*/}/.git;\
	fi

package-publish: package
	@FRONTEND_APP_VERSION=$$(cd ${FRONTEND} && make -s version | awk '{print $$NF}');\
	PACKAGE=${APP_GROUP}-${APP_VERSION}-$$FRONTEND_APP_VERSION.tar.gz;\
	make -C ${APP_PATH}/${GIT_TOOLS} storage-push\
		FILE=${APP_PATH}/$$PACKAGE\
		STORAGE_OPTIONS="--s3-acl=public-read"\
		STORAGE_BUCKET=matchid-dist STORAGE_ACCESS_KEY=${STORAGE_ACCESS_KEY} STORAGE_SECRET_KEY=${STORAGE_SECRET_KEY};\
	if [ "${GIT_BRANCH}" = "${GIT_BRANCH_MASTER}" ]; then\
		ln -s $$PACKAGE ${APP_PATH}/${APP_GROUP}-latest.tar.gz;\
		make -C ${APP_PATH}/${GIT_TOOLS} storage-push\
			FILE=${APP_PATH}/${APP_GROUP}-latest.tar.gz\
			STORAGE_OPTIONS="--copy-links --s3-acl=public-read"\
			STORAGE_BUCKET=matchid-dist STORAGE_ACCESS_KEY=${STORAGE_ACCESS_KEY} STORAGE_SECRET_KEY=${STORAGE_SECRET_KEY};\
	fi

depackage:
	@if [ ! -f "/usr/bin/rclone" ]; then\
		if [ "${OS_TYPE}" = "DEB" ]; then\
			sudo dpkg -i rclone-current-linux-amd64.deb;\
		fi;\
		if [ "${OS_TYPE}" = "RPM" ]; then\
			sudo yum localinstall -y rclone-current-linux-amd64.rpm;\
		fi;\
	fi
	@if [ -z "$(wildcard /usr/bin/docker-compose /usr/local/bin/docker-compose)" ];then\
		mkdir -p ${HOME}/.local/bin && cp docker-compose ${HOME}/.local/bin/docker-compose;\
		chmod +x ${HOME}/.local/bin/docker-compose;\
	fi;
	@make config
	@ls ${DC_DIR}/*.tar.gz | xargs -L 1 sudo -u $$USER docker load -i;
	@echo you can now start all service using 'make up';

logs: backend
	@docker logs ${DC_PREFIX}-${APP}

example-download:
	@echo downloading example code
	@mkdir -p ${EXAMPLES}
	@cd ${EXAMPLES}; git clone -q https://github.com/matchID-project/examples . ; true
	@mv projects _${date}_${id}_projects 2> /dev/null; true
	@mv upload _${date}_${id}_upload 2> /dev/null; true
	@ln -s ${EXAMPLES}/projects ${BACKEND}/projects
	@ln -s ${EXAMPLES}/data ${BACKEND}/upload

recipe-run: backend
	docker exec -i ${USE_TTY} ${DC_PREFIX}-backend curl -s -XPUT http://localhost:${PORT}/matchID/api/v0/recipes/${RECIPE}/run && echo ${RECIPE} run

deploy-local: config up local-test-api

local-test-api:
	@make -C ${APP_PATH}/${GIT_TOOLS} local-test-api \
		PORT=${PORT} \
		API_TEST_PATH=${API_TEST_PATH} API_TEST_JSON_PATH=${API_TEST_JSON_PATH} API_TEST_DATA=''\
		${MAKEOVERRIDES}

deploy-remote-instance: config frontend-config
	@FRONTEND_APP_VERSION=$$(cd ${FRONTEND} && make -s version | awk '{print $$NF}');\
	make -C ${APP_PATH}/${GIT_TOOLS} remote-config\
			APP=${APP} APP_VERSION=${APP_VERSION} CLOUD_TAG=front:$$FRONTEND_APP_VERSION-back:${APP_VERSION}\
			DC_IMAGE_NAME=${DC_IMAGE_NAME}\
			GIT_BRANCH="${GIT_BRANCH}" ${MAKEOVERRIDES}

deploy-remote-services:
	@make -C ${APP_PATH}/${GIT_TOOLS} remote-deploy remote-actions\
		APP=${APP} APP_VERSION=${APP_VERSION}\
		ACTIONS="config up" SERVICES="elasticsearch postgres backend" GIT_BRANCH="${GIT_BRANCH}" ${MAKEOVERRIDES}
	@FRONTEND_APP_VERSION=$$(cd ${FRONTEND} && make -s version | awk '{print $$NF}');\
		make -C ${APP_PATH}/${GIT_TOOLS} remote-deploy remote-actions\
		APP=${GIT_FRONTEND} APP_VERSION=$$FRONTEND_APP_VERSION DC_IMAGE_NAME=${FRONTEND_DC_IMAGE_NAME}\
		ACTIONS="${GIT_FRONTEND}" GIT_BRANCH="${GIT_FRONTEND_BRANCH}" ${MAKEOVERRIDES}

deploy-remote-publish:
	@if [ -z "${NGINX_HOST}" -o -z "${NGINX_USER}" ];then\
		(echo "can't deploy without NGINX_HOST and NGINX_USER" && exit 1);\
	fi;
	make -C ${APP_PATH}/${GIT_TOOLS} remote-test-api-in-vpc nginx-conf-apply remote-test-api\
		APP=${APP} APP_VERSION=${APP_VERSION} GIT_BRANCH="${GIT_BRANCH}" PORT=${PORT}\
		APP_DNS=${APP_DNS} API_TEST_PATH=${API_TEST_PATH} API_TEST_JSON_PATH=${API_TEST_JSON_PATH} API_TEST_DATA=''\
		${MAKEOVERRIDES}

deploy-delete-old:
	@make -C ${APP_PATH}/${GIT_TOOLS} cloud-instance-down-invalid\
		APP=${APP} APP_VERSION=${APP_VERSION} GIT_BRANCH="${GIT_BRANCH}" ${MAKEOVERRIDES}

deploy-monitor:
	@make -C ${APP_PATH}/${GIT_TOOLS} remote-install-monitor-nq NQ_TOKEN=${NQ_TOKEN} ${MAKEOVERRIDES}

deploy-remote: config deploy-remote-instance deploy-remote-services deploy-remote-publish deploy-delete-old deploy-monitor

clean-remote:
	@make -C ${APP_PATH}/${GIT_TOOLS} remote-clean ${MAKEOVERRIDES} > /dev/null 2>&1 || true
