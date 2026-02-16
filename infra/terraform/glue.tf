# Need glue a database as a Iceberg Catalog until https://github.com/datahub-project/datahub/issues/14849 is addressed

#---------------------------------------------------------------
# Glue Database for Iceberg Tables
#---------------------------------------------------------------
resource "aws_glue_catalog_database" "data_on_eks" {
  count       = var.enable_glue_catalog ? 1 : 0
  name        = replace(local.name, "-", "_")
  description = "Database for ${local.name} Iceberg tables"
}
