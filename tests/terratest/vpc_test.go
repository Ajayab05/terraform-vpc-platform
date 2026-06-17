package test

import (
  "testing"

  "github.com/gruntwork-io/terratest/modules/terraform"
  "github.com/stretchr/testify/assert"
)

func TestVpc(t *testing.T) {

  terraformOptions := terraform.WithDefaultRetryableErrors(
    t,
    &terraform.Options{
      TerraformDir: "../../environments/prod",
    },
  )

  terraform.InitAndPlan(t, terraformOptions)

  vpcId := terraform.Output(t, terraformOptions, "vpc_id")

  assert.NotEmpty(t, vpcId)
}