TF=terraform
all:  init plan apply
apply:
	$(TF) apply 

plan:
	$(TF) plan 

init:
	$(TF) init 

del:
	$(TF) destroy
