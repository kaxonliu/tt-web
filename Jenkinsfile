pipeline {
    agent {
        kubernetes {
            label "jenkins-slave-${UUID.randomUUID().toString().take(8)}"
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins-slave: dynamic
spec:
  serviceAccountName: jenkins
  containers:
  # JNLP 通信容器，必须存在
  - name: jnlp
    image: jenkins/inbound-agent:3355.v388858a_47b_33-3-jdk21
    args: ["$(JENKINS_SECRET)", "$(JENKINS_NAME)"]
  - name: python-3-11-slim
    image: python:3.11-slim
    imagePullPolicy: IfNotPresent
    command: ['cat']
    tty: true
  - name: kaniko
    image: gcr.io/kaniko-project/executor
    imagePullPolicy: IfNotPresent
    command: ['/busybox/cat']
    tty: true
    env:
    - name: DOCKER_CONFIG
      value: /home/user/.docker
    volumeMounts:
     - name: docker-config
       mountPath: /home/user/.docker/
     - name: kaniko-secret
       mountPath: /secret
  - name: kubectl
    image: alpine/kubectl
    imagePullPolicy: IfNotPresent
    command: ['cat']
    tty: true
  volumes:
    - name: docker-config
      secret:
        secretName: registry-secret
        items:
          - key: .dockerconfigjson
            path: config.json
    - name: kaniko-secret
      secret:
        secretName: registry-secret
"""
        }
    }
    
    environment {
        // 定义环境变量
        REGISTRY_URL = '192.168.43.80:30002'
        IMAGE_ENDPOINT = 'pythonwebproject/tt-web'
    }
    
    stages {
        stage('Prepare') {
            steps {
                script {
                    // 检出代码并获取分支信息
                    def scmVars = checkout scm
                    // 获取远程分支名（如 origin/main 或 origin/develop）
                    env.GIT_BRANCH = scmVars.GIT_BRANCH
                    
                    // 如果 checkout scm 没有返回 GIT_BRANCH，使用其他方法获取
                    if (!env.GIT_BRANCH) {
                        env.GIT_BRANCH = sh(script: 'git symbolic-ref --short HEAD 2>/dev/null || git describe --all --exact-match HEAD', returnStdout: true).trim()
                    }
                    
                    echo "------------>本次构建的分支是：${env.GIT_BRANCH}"
                    
                    // 获取 git commit id 作为镜像 tag
                    env.IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE = "${REGISTRY_URL}/${IMAGE_ENDPOINT}:${env.IMAGE_TAG}"
                    echo "镜像标签：${env.IMAGE_TAG}"
                    echo "完整镜像：${env.IMAGE}"
                }
            }
        }
        
        stage('Build') {
            steps {
                container('docker') {
                    echo "3. 构建镜像"
                    script {
                        withCredentials([usernamePassword(
                            credentialsId: 'harbor-auth',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASSWORD'
                        )]) {
                            // 检查 docker daemon 是否可用
                            sh """
                                echo "检查 Docker daemon 连接..."
                                docker version || echo "Docker 命令失败"
                                echo "当前用户: \$(whoami)"
                                ls -la /var/run/docker.sock 2>/dev/null || echo "docker.sock 不存在"
                            """
                            
                            // 构建镜像
                            sh "docker build -t ${env.IMAGE} ."
                        }
                    }
                }
            }
        }
        
        stage('Push') {
            steps {
                container('docker') {
                    echo "4. 推送镜像"
                    withCredentials([usernamePassword(
                        credentialsId: 'harbor-auth',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        sh """
                            docker login ${REGISTRY_URL} -u ${DOCKER_USER} -p ${DOCKER_PASSWORD}
                            docker push ${env.IMAGE}
                        """
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                container('kubectl') {
                    script {
                        echo "当前分支：${env.GIT_BRANCH}"
                        
                        if (env.GIT_BRANCH == 'origin/master') {
                            echo "部署到生产K8S集群"
                            withCredentials([file(
                                credentialsId: 'kubeconfig-prod',
                                variable: 'KUBECONFIG'
                            )]) {
                                sh """
                                    mkdir -p ~/.kube
                                    cp '${KUBECONFIG}' ~/.kube/config
                                    # 检查 kubeconfig
                                    kubectl config view --minify
                                    # 替换镜像标签并部署
                                    sed -i 's/<BUILD_TAG>/${env.IMAGE_TAG}/g' ./k8s/prod.yaml
                                    echo "应用生产配置："
                                    cat ./k8s/prod.yaml
                                    kubectl apply -f ./k8s/prod.yaml --record
                                """
                                echo "部署完成"
                            }
                        } else if (env.GIT_BRANCH == 'origin/develop') {
                            echo "部署到测试K8S集群"
                            withCredentials([file(
                                credentialsId: 'kubeconfig-dev-test',
                                variable: 'KUBECONFIG'
                            )]) {
                                sh """
                                    mkdir -p ~/.kube
                                    cp '${KUBECONFIG}' ~/.kube/config
                                    # 检查 kubeconfig
                                    kubectl config view --minify
                                    # 替换镜像标签并部署
                                    sed -i 's/<BUILD_TAG>/${env.IMAGE_TAG}/g' ./k8s/dev.yaml
                                    echo "应用测试配置："
                                    cat ./k8s/dev.yaml
                                    kubectl apply -f ./k8s/dev.yaml --record
                                """
                            }
                        } else {
                            echo "分支 ${env.GIT_BRANCH} 没有对应的部署配置，跳过部署"
                        }
                    }
                }
            }
        }
    }
    
    post {
        failure {
            echo "构建失败 - ${currentBuild.fullDisplayName}"
        }
        success {
            echo "构建成功!"
        }
    }
}