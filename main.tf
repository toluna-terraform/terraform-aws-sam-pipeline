locals {
  artifacts_bucket_name = "s3-codepipeline-${var.app_name}-${var.env_type}"
}



module "code-pipeline" {
  source                   = "./modules/codepipeline"
  env_name                 = var.env_name
  app_name                 = var.app_name
  env_type                 = var.env_type
  source_repository        = var.source_repository
  s3_bucket                = data.aws_s3_bucket.codepipeline_bucket.bucket
  code_build_projects      = [module.build-code-build.attributes.name, module.build-post-build.attributes.name]
  code_deploy_applications = []
  trigger_branch           = var.trigger_branch
  trigger_events           = ["push", "merge"] // change same as ecs
  parameter_overrides      = var.parameter_overrides
  pipeline_type            = var.pipeline_type
  run_stress_tests         = var.run_stress_tests
  run_integration_tests    = var.run_integration_tests
}

module "build-code-build" {
  source                                = "./modules/codebuild"
  codebuild_name                        = "sam-build-${var.app_name}"
  env_name                              = var.env_name
  s3_bucket                             = data.aws_s3_bucket.codepipeline_bucket.bucket
  privileged_mode                       = true
  environment_variables_parameter_store = {}
  codedeploy_role                       = var.codedeploy_role
  environment_variables                 = merge(var.environment_variables, { APPSPEC = "" })
  enable_jira_automation                = var.enable_jira_automation
  buildspec_file = templatefile("buildspec-build.yml.tpl",
    { APP_NAME           = var.app_name,
      ENV                = var.env_name, FROM_ENV = var.from_env,
      RUNTIME_TYPE       = var.runtime_type,
      RUNTIME_VERSION    = var.runtime_version,
      TEMPLATE_FILE_PATH = var.template_file_path,
      S3_BUCKET          = data.aws_s3_bucket.codepipeline_bucket.bucket,
      ADO_USER           = data.aws_ssm_parameter.ado_user.value,
      ADO_PASSWORD       = data.aws_ssm_parameter.ado_password.value,
      SLN_PATH           = var.solution_file_path,
      PIPELINE_TYPE      = var.pipeline_type
  })
}

module "build-post-build" {
  source                                = "./modules/codebuild"
  env_name                              = var.env_name
  codebuild_name                        = "post-sam-build-${var.app_name}"
  s3_bucket                             = "s3-codepipeline-${var.app_name}-${var.env_type}"
  privileged_mode                       = true
  environment_variables_parameter_store = {}
  codedeploy_role                       = var.codedeploy_role
  environment_variables                 = merge(var.environment_variables, { APPSPEC = "" })
  enable_jira_automation                = var.enable_jira_automation

  buildspec_file = templatefile("${path.module}/templates/post_buildspec.yml.tpl",
    { APP_NAME               = var.app_name,
      ENV                    = split("-", var.env_name)[0],
      FROM_ENV               = var.from_env,
      FROM_ENV               = var.from_env,
      RUNTIME_TYPE           = var.runtime_type,
      RUNTIME_VERSION        = var.runtime_version,
      TEMPLATE_FILE_PATH     = var.template_file_path,
      S3_BUCKET              = data.aws_s3_bucket.codepipeline_bucket.bucket,
      ADO_USER               = data.aws_ssm_parameter.ado_user.value,
      ADO_PASSWORD           = data.aws_ssm_parameter.ado_password.value,
      SLN_PATH               = var.solution_file_path,
      PIPELINE_TYPE          = var.pipeline_type,
      ENABLE_JIRA_AUTOMATION = var.enable_jira_automation
  })
}

resource "null_resource" "detach_vpc" {
  triggers = {
    function    = "${var.app_name}-${var.env_name}",
    aws_profile = "${var.aws_profile}",
    env_name    = "${var.env_name}"
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = "aws lambda update-function-configuration --function-name ${self.triggers.function} --vpc-config 'SubnetIds=[],SecurityGroupIds=[]' --profile ${self.triggers.aws_profile} && sleep 30"
  }
  depends_on = [
    module.code-pipeline
  ]
}
