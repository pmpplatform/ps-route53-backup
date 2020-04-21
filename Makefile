VERSION ?= "v1.0.0"

docker:
	docker build --build-arg version="$(VERSION)" -t pasientskyhosting/ps-route53-backup:latest . && \
	docker build --build-arg version="$(VERSION)" -t pasientskyhosting/ps-route53-backup:"$(VERSION)" .

docker-run:
	docker run pasientskyhosting/ps-route53-backup:"$(VERSION)"

docker-push: docker
	docker push pasientskyhosting/ps-route53-backup:"$(VERSION)" && \
	docker push pasientskyhosting/ps-route53-backup:latest