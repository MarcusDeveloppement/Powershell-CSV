# Demande à l'admin le chemin du fichier CSV
$csvPath = Read-Host "Chemin complet du fichier CSV (ex: C:\Script\utilisateurs.csv)"

if (-Not (Test-Path $csvPath)) {
    Write-Host "Le fichier spécifié n'existe pas. Vérifiez le chemin." -ForegroundColor Red
    exit
}

# Mapping des services pour avoir les noms exacts des OU dans AD
$OUmap = @{
    "IT"             = "IT"
    "Comptabilité"   = "Comptabilité"
    "Marketing"      = "Marketing"
    "Ressources Humaines" = "Ressources Humaines"
}

# Ajout du fichier de log
$logPath = "C:\Users\Administrateur\Desktop\import_log.csv"
"Nom;Service;Résultat" | Out-File $logPath -Encoding UTF8

# Lecture du CSV
$users = Import-Csv -Delimiter "," -Path $csvPath

foreach ($user in $users) {
    $givenname = $user.Prenom
    $surname = $user.Nom
    $fullname = "$givenname $surname"
    $samBase = ($givenname.Substring(0,1) + "." + $surname).ToLower()
    $sam = $samBase
    $upn = "$sam@m2i.fr"
    $password = $user.Motdepasse
    $phone = $user.Telephone
    $service = $user.Service

    # Ajout Vérification service existant dans dictionnaire

    if (-not $OUmap.ContainsKey($service)) {
        Write-Host "Service inconnu pour $fullname : $service" -ForegroundColor Yellow
        "$fullname;$service;Service inconnu" | Out-File $logPath -Append
        continue
    }

    $ou = $OUmap[$service]
    $ouPath = "OU=$ou,OU=Entreprise,DC=entreprise,DC=fr"


    # Gérer les doublons des utilisateurs principaux
    $i = 1
    while (Get-ADUser -Filter { UserPrincipalName -eq $upn }) {
        $sam = "$samBase$i"
        $upn = "$sam@m2i.fr"
        $i++
    }

    try {
        New-ADUser -Name $fullname `
                   -GivenName $givenname `
                   -Surname $surname `
                   -DisplayName $fullname `
                   -SamAccountName $sam `
                   -UserPrincipalName $upn `
                   -EmailAddress $upn `
                   -Department $service `
                   -OfficePhone $phone `
                   -Path $ouPath `
                   -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) `
                   -Enabled $true

        Write-Host "Utilisateur ajouté : $fullname" -ForegroundColor Green
        "$fullname;$service;Ajouté avec succès" | Out-File $logPath -Append
    }
    catch {
        Write-Host "ERREUR lors de l'ajout de : $fullname" -ForegroundColor Red
        "$fullname;$service;Erreur - $($_.Exception.Message)" | Out-File $logPath -Append
    }
}
