## 실행 방법
* 실행 환경
    * 빌드 환경
        * OS: windows 10
        * Docker Desktop 및 Gradle 8.5 설치
    * 실행 환경
        * OS: Ubuntu 18.04
        * k8s v1.23.0 버전 설치
* 어플리케이션 및 도커 이미지 빌드
    ```shell
    # 어플리케이션 빌드
    $ ./gradlew build

    # 도커이미지 빌드
    $ docker build -t <tag-name> .
    ```

## gradle을 사용하여 어플리케이션과 도커이미지를 빌드
### 어플리케이션을 빌드
* 패키지 매니저를 Maven에서 Gradle로 변환
    * 의존성 및 패키징 구성
    * Test 및 Jacoco 구성
    * Spotless 구성
### 도커이미지 빌드
* Dockerfile 생성하여 도커이미지 빌드
    * 실행 계정 `uid:999` 생성
    * 디렉토리 및 jar 파일 소유자 설정
## 어플리케이션의 log는 host의 `/logs` 에 적재
* Spring Boot 로그 파일 출력 설정
    ```yaml
    # ConfigMap 
    data:
      logging-file-name: ./logs/spring-${HOSTNAME}.log
    
    # Deployments 
    containers:
      - name: app
        image: hanum20/spring-petclinic-data-jdbc:latest
        env:
        - name: LOGGING_FILE_NAME
          valueFrom:
            configMapKeyRef:
                name: app
                key: logging-file-name
    ```
* Pods의 VolumeMount로 host의 `/logs` 디렉토리 마운트 설정
    ```yaml
    # Deployments 
    containers:
      - name: app
        image: hanum20/spring-petclinic-data-jdbc:latest
        volumeMounts:
        - name: log-dir
          mountPath: /app/logs
    volumes:
    - name: log-dir
      hostPath:
        type: DirectoryOrCreate
        path: /logs
    ```
    * initContainer로 마운트 대상 디렉토리의 소유자를 `uid:999`로 변경 처리
## 정상 동작 여부를 반환하는 api를 구현하며, 10초에 한 번씩 체크
* Spring Boot의 Health Probe(Liveness, Readiness) 활성화
    * Spring Boot Actuator의 기능을 사용
* Pods에서 livenessProbe, readinessProbe로 10초 간격으로 체크하도록 설정
    ```yaml
    # Deployment
    containers:
      - name: app
        image: hanum20/spring-petclinic-data-jdbc:latest
        livenessProbe:
          httpGet:
            path: /manage/health/liveness
            port: 8080
          failureThreshold: 5
          initialDelaySeconds: 30
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 6
        readinessProbe:
          httpGet:
          path: /manage/health/readiness
          port: 8080
          failureThreshold: 5
          initialDelaySeconds: 30
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 2
    ```

## 종료 시 30초 이내에 프로세스가 종료되지 않으면 SIGKILL로 강제 종료
* Pods의 종료 프로세스에서 SIGTERM이 Pods로 전달되면 설정 된 `terminationGracePeriodSeconds` 이내로 종료되지 않으면, SIGKILL 신호를 전송 함.
    * `terminationGracePeriodSeconds`의 기본값은 30
## 배포 시 scale-in, out 상황에서 유실되는 트래픽은 없어야 함
* Pods의 livenessProbe, readinessProbe를 체크하여 트래픽 처리 준비가 되어있지 않으면, 트래픽이 차단 됨
* scale-in으로 인해 Pods 종료 시, 해당 Pods의 App이 기존에 처리하던 트래픽은 마무리 하도록 Spring Boot에서 `graceful shutdown` 활성화
    * spring boot에서 graceful shutdown timeout 기본값은 30으로 설정되어있음
## 어플리케이션 프로세스는 root 계정이 아닌 uid:999로 실행
* Pod에서 securityContext로 `runAsUser` 및 `runAsGroup`를 설정하여 `uid:999` 계정으로 실행 
## DB도 kubernetes에서 실행하며 재 실행 시에도 변경된 데이터는 유실되지 않도록 설정
* PV, PVC를 구성하여 DB 재시작 시에도 데이터가 유지되도록 구성
    * bare metal 환경이라 StorageClass는 `local-storage`를 사용하였음 
## 어플리케이션과 DB는 cluster domain으로 통신
* Application의 DB URL 정보를 cluster domain으로 설정
    ```yaml
    # ConfigMap
    data: 
      spring-datasource-url: jdbc:mysql://mysql-0.mysql.default.svc.cluster.local/petclinic
    ```
## ingress-controller를 통해 어플리케이션에 접속이 가능해야 함
* bare metal 환경의 ingress-controller를 설치하여 환경 구성
    * ingress-controller의 service가 NodePort 형식으로 생성 됨
* ingress를 생성하여 서비스를 노출
## namespace는 default를 사용
* 모든 리소스를 default namespace로 생성하였음