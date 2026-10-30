# Guia de Deploy na AWS (AWS Academy) - Loja Gamer

Passo a passo prático para subir a infraestrutura na AWS e colocar a aplicação no ar para a aula.

---

## 1. O que será criado na AWS

A arquitetura segue o modelo padrão exigido em avaliações de DevOps e Cloud:

- **VPC** dedicada (`10.0.0.0/16`) com Internet Gateway.
- **2 Subnets Públicas** (em AZs diferentes) para a EC2.
- **2 Subnets Privadas** (em AZs diferentes) exclusivas para o RDS MySQL.
- **Security Group da EC2**: libera portas 80 (HTTP) e 22 (SSH).
- **Security Group do RDS**: libera a porta 3306 **apenas** para o Security Group da EC2 (o banco não fica exposto para a internet).
- **Bucket S3 privado**: para armazenar as imagens dos produtos (`lojagamer-imagens-<account-id>`).
- **RDS MySQL 8.0**: banco privado sem IP público, usuário `admin`, senha `LojaGamer2026`.
- **EC2 (Amazon Linux 2023)**: usando a role nativa do Academy (`LabInstanceProfile`), já inicializando com Docker instalado e o arquivo `.env` configurado.

---

## 2. Passo 1: Subir a infraestrutura no CloudFormation (5 minutos)

1. Entre no console da **AWS Academy** e clique em **AWS** para abrir o console.
2. Certifique-se de estar na região **us-east-1** (N. Virginia), que é a padrão do Academy.
3. No campo de busca do console, pesquise por **CloudFormation**.
4. Clique em **Create stack** -> **With new resources (standard)**.
5. Em *Template source*, marque **Upload a template file**.
6. Clique em **Choose file** e selecione o arquivo:
   `deploy/aws-infrastructure.yaml` deste projeto.
7. Clique em **Next**.
8. Preencha os parâmetros:
   - **Stack name**: `lojagamer`
   - **KeyName**: `vockey` *(é a chave padrão que já existe no AWS Academy)*
   - **DBPassword**: `LojaGamer2026`
9. Clique em **Next**, avance a próxima tela e clique em **Submit**.

> ⏳ O CloudFormation vai criar a VPC, as subnets, o S3, o RDS e a EC2. O processo leva em torno de 8 a 10 minutos por conta da inicialização do RDS.
>
> Quando o status estiver em **CREATE_COMPLETE**, vá na aba **Outputs**.
> Anote o **EC2PublicIP** (IP público da sua EC2).

---

## 3. Passo 2: Acessar a EC2

Você tem duas maneiras bem simples de acessar a máquina:

### Opção A: Pelo próprio navegador (Mais fácil, sem precisar de arquivo de chave)
1. No console da AWS, vá no serviço **EC2** -> **Instances**.
2. Selecione a instância `ec2-lojagamer`.
3. Clique no botão **Connect** (Conectar) no canto superior direito.
4. Na aba **EC2 Instance Connect**, deixe o usuário como `ec2-user` e clique em **Connect**.
5. Um terminal Linux abrirá direto no seu navegador!

### Opção B: Por SSH usando a chave do Academy
1. No painel inicial do AWS Academy (onde tem o botão vermelho *Start Lab*), clique em **AWS Details** (ao lado do círculo verde).
2. Ao lado de **SSH Key**, clique em **Download PEM** e salve o arquivo como `vockey.pem`.
3. Conecte pelo terminal do seu computador:
   ```bash
   ssh -i vockey.pem ec2-user@<IP_PUBLICO_DA_EC2>
   ```

---

## 4. Passo 3: Colocar a aplicação para rodar

Dentro da EC2 (seja pelo terminal do navegador ou por SSH), a máquina já está com o Docker instalado e o arquivo `/opt/lojagamer/.env` pronto com a conexão do banco e do S3.

Para subir a loja:

1. Clone o repositório ou envie os arquivos para a EC2:
   ```bash
   git clone <URL_DO_SEU_GITHUB_OU_REPOSITORIO> ~/lojagamer
   cd ~/lojagamer
   ```
   *(Caso não tenha no GitHub, você pode copiar os arquivos via SCP ou subir pelo terminal).*

2. Faça o build da imagem Docker:
   ```bash
   docker build -t lojagamer:latest .
   ```

3. Suba o container apontando para as configurações de produção:
   ```bash
   docker run -d --name lojagamer --restart unless-stopped \
     --env-file /opt/lojagamer/.env \
     -p 80:8080 \
     lojagamer:latest
   ```

4. Verifique se o container subiu certinho:
   ```bash
   docker ps
   docker logs lojagamer
   ```

> 💡 **O que acontece na primeira inicialização**:
> O backend em Go detecta que o banco está vazio, roda as migrations (cria as tabelas e cadastra os 50 produtos) e envia automaticamente todas as fotos dos produtos da pasta `seed-images/` para o bucket S3!

---

## 5. Validação na Aula

Abra no navegador do seu computador:

1. **Loja Gamer**:
   ```
   http://<IP_PUBLICO_DA_EC2>
   ```
2. **Healthcheck** (mostra conexão com MySQL e S3 funcionando):
   ```
   http://<IP_PUBLICO_DA_EC2>/healthz
   ```
3. **Área Admin** (token: `admin123`):
   ```
   http://<IP_PUBLICO_DA_EC2>/admin
   ```
4. **Métricas Prometheus**:
   ```
   http://<IP_PUBLICO_DA_EC2>/metrics
   ```

---

## 6. O que responder se o professor perguntar sobre as boas práticas:

- **Por que o RDS está em subnet privada?**
  Para isolamento de camada de dados. Ninguém na internet consegue conectar na porta 3306 do banco.
- **Como a EC2 se comunica com o RDS?**
  Pela rota interna da VPC e pelo Security Group do RDS, que autoriza exclusivamente o tráfego que vem do Security Group da EC2 (`SourceSecurityGroupId`).
- **Por que o bucket S3 é privado?**
  Todas as fotos ficam protegidas sem acesso público direto. A aplicação em Go lê as fotos via SDK da AWS e serve para o usuário na rota `/images/...`.
- **Onde ficam salvas as credenciais da AWS na EC2?**
  Não usamos chaves estáticas (`ACCESS_KEY` ou `SECRET_KEY`). A EC2 usa uma IAM Instance Profile (`LabInstanceProfile`), que assume credenciais temporárias de forma transparente e segura.
