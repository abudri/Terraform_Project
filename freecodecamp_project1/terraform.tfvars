# last part of FreeCodeCamp Terraform Course: https://youtu.be/SLB_c_ayRMo?t=7808

# using list (array basically) objects for variables, last part of Course
subnet_prefix = [{ cidr_block = "10.0.8.0/24", name = "prod_subnet"},
  { cidr_block = "10.0.9.0/24", name = "dev_subnet"}
]