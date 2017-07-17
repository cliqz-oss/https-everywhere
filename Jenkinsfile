node {

  stage 'checkout'

  checkout([$class: 'GitSCM', branches: [[name: '*/cliqz-ci']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: '../workspace@script/xpi-sign']], submoduleCfg: [], userRemoteConfigs: [[credentialsId: XPI_SIGN_CREDENTIALS, url: XPI_SIGN_REPO_URL]]])

  stage 'build'

  def imgName = "cliqz-oss/https-everywhere:${env.BUILD_TAG}"
  def balrogCredentialsID = '774bccf1-ae66-41e1-9f2e-f8efb4bedc21'

  dir("../workspace@script") {
    sh 'rm -fr secure'
    sh 'cp -R /cliqz secure'

    docker.build(imgName, ".")

    withCredentials([
        usernamePassword(
            credentialsId: balrogCredentialsID, 
            passwordVariable: 'BALROG_PASSWORD', 
            usernameVariable: 'BALROG_ADMIN')]) {

            docker.image(imgName).inside("-u 0:0") {
              sh './install-dev-dependencies.sh'
              sh '/bin/bash ./cliqz/build_sign_and_publish.sh '+CLIQZ_CHANNEL
            }
    }

    sh 'rm -rf secure'
  }
}
