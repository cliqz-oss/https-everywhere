node {

  stage 'checkout'

  checkout([
    $class: 'GitSCM', 
    branches: [[name: '*/cliqz-ci']], 
    doGenerateSubmoduleConfigurations: false, 
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: '../workspace@script/xpi-sign']], 
    submoduleCfg: [], userRemoteConfigs: [[credentialsId: XPI_SIGN_CREDENTIALS, url: XPI_SIGN_REPO_URL]]])

  
  stage 'build'

  def imgName = "cliqz-oss/https-everywhere:${env.BUILD_TAG}"

  dir("../workspace@script") {
    sh 'rm -fr secure'
    sh 'cp -R /cliqz secure'

    docker.build(imgName, ".")

    docker.image(imgName).inside("-u 0:0") {
      sh './install-dev-dependencies.sh'

      withCredentials([
          file(credentialsId: '173621c3-7549-4e29-8005-04175db53e37', variable: 'XPISIGN_CERT'), 
          file(credentialsId: '3496a127-ea1c-40ab-95ee-7c830dea2a40', variable: 'XPISIGN_PASS'), 
          [$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: '62c70c1d-7d0a-4eb8-9987-38288ebf25cf', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'], 
          file(credentialsId: '368f4e39-a1c0-4e11-bafa-e14be548e3ae', variable: 'BALROG_CREDS')]) {

          sh '/bin/bash ./cliqz/build_sign_and_publish.sh '+CLIQZ_CHANNEL
      }
    }

    sh 'rm -rf secure'
  }
}
