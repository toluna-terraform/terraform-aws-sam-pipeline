version: 0.2
phases:
  install:
    runtime-versions:
      "${RUNTIME_TYPE}": "${RUNTIME_VERSION}" 
  pre_build:
    commands:
      - CODEBUILD_RESOLVED_SOURCE_VERSION="$CODEBUILD_RESOLVED_SOURCE_VERSION"
      - RUNTIME="${RUNTIME_TYPE}-${RUNTIME_VERSION}"
  build:
    commands:
      - echo Build started on `date`
      - sam package --template-file "${TEMPLATE_FILE_PATH}/template.yaml" --output-template-file package.yml --s3-bucket "${S3_BUCKET}"

artifacts:
  files:
    - package.yml
    - ${TEMPLATE_FILE_PATH}/samconfig.toml
  discard-paths: yes