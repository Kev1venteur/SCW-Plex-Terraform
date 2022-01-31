# SCW-Plex-Terraform
:key: Ce repo fournit le fichier Terraform pour déployer sur Scaleway l'infrastructure illustrée ci-dessous : 

<p align="center">
  <img src="annexes/images/Infra.png?style=centerme">
</p>

## Prérequis
Installez la CLI Scaleway
```bash
# Récupération de l'utilitaire
sudo curl -o /usr/local/bin/scw -L "https://github.com/scaleway/scaleway-cli/releases/download/v2.4.0/scw-2.4.0-linux-x86_64"
# Ajout des droits d'éxécution
sudo chmod +x /usr/local/bin/scw
# Initialisation de la CLI (il faudra rentrer vos indentifiants Scaleway)
scw init
```

## Kickstart

```BASH
# Pour commencer, clonez le repo
git clone https://github.com/Kev1venteur/SCW-Plex-Terraform.git && cd SCW-Plex-Terraform
#----------------------TERRAFORM-------------------------#
# Lancez ensuite l'initialisation de Terraform
terraform init
# Vérifiez la syntaxe du fichier main
terraform plan
# Appliquez la configuration du fichier "main.tf" chez Scaleway
terraform apply
# (Optionnel) Détruisez ce que vous venez de créer
terraform destroy
```

## Resultats

Vous allez exécuter des commandes kubectl, et devez donc avoir l'outil installé. <br />
Vous pouvez retrouver un tuto [ici](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/).
```BASH
# Pour voir les résultats de ce que vous venez de créer, placez vous à la racine du repo.
# Copiez le fichier "kubeconfig" que terraform vient de récupérer vers "~/.kube/config" :
cp kubeconfig ~/.kube/config
# Admirez :
kubectl get svc --all-namespaces
```
Vous devriez avoir quelque chose comme cela :
<p align="center">
  <img src="annexes/images/svc-results.png?style=centerme">
</p>
Vous pouvez observer qu'il n'y a qu'une instance plex.<br />
C'est normal notre cluster est scalable, il se créer avec 3 instances,<br />
peut monter à 5 en charge et ne garder qu'une istance s'il n'y a aucune activité.<br /><br />

A savoir que les instances créées sont sans GPU pour faire des économies.<br />
Il est toutefois possible de modifier ce paramètre [ici](main.tf#L46).

## Debug

#### Augmentez le niveau de log de Terraform

Avant de lancer Terraform définissez la variable d'environnement 'TF_LOG'.

```bash
export TF_LOG=DEBUG
```

