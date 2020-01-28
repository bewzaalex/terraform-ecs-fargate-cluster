all: help

# make help - show help message
.PHONY: help
help:
	@printf "\nAvailable targets:\n\n"
	@egrep "^# make " [Mm]akefile | sed -e 's/^#\ //g'
	@printf "\n"

# make tf/init - initialize terraform working directory
.PHONY: tf/init
tf/init:
	terraform init --reconfigure

# make tf/plan - show plan for terraform execution
.PHONY: tf/plan
tf/plan:
	terraform plan

# make tf/apply - apply terraform execution plan
.PHONY: tf/apply
tf/apply:
	terraform validate && terraform apply -auto-approve

# make tf/destroy - destroy all infrastructure created by terraform
.PHONY: tf/destroy
tf/destroy:
	terraform validate && terraform destroy -auto-approve
