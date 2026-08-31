variable "aws_region" {
  description = "Region AWS du socle de state"
  type        = string
  default     = "eu-west-3"
}

variable "owner" {
  description = "Proprietaire des ressources, pour le taggage"
  type        = string
  default     = "platform-engineering"
}

variable "kms_deletion_window_days" {
  description = "Delai avant suppression effective de la cle KMS"
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_days >= 7 && var.kms_deletion_window_days <= 30
    error_message = "AWS impose un delai entre 7 et 30 jours."
  }
}

variable "additional_key_user_arns" {
  description = "ARNs supplementaires autorises a chiffrer/dechiffrer les states (ex: role OIDC GitHub Actions), en plus de l'operateur courant"
  type        = list(string)
  default     = []
}
