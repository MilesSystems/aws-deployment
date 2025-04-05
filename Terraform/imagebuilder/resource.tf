resource "aws_imagebuilder_image_pipeline" "image_pipeline" {
  description = "An image pipeline is the automation configuration for building secure OS images on AWS."
  distribution_configuration_arn = var.distribution_configuration_id
  enhanced_image_metadata_enabled = true
  image_recipe_arn = aws_imagebuilder_image_recipe.ec2_image_recipe.arn
  image_tests_configuration {
    image_tests_enabled = true
  }
  infrastructure_configuration_arn = var.infrastructure_configuration_id
  name = var.name
  status = "ENABLED"
}

resource "aws_imagebuilder_image_recipe" "ec2_image_recipe" {
  block_device_mapping = [
    {
      device_name = "/dev/xvda"
      ebs =       ebs {
        volume_type = "gp2"
        volume_size = var.storage
        delete_on_termination = true
      }
    }
  ]
  component = [
    {
      component_arn = aws_imagebuilder_component.install_dependencies_component.arn
    }
  ]
  description = "String"
  name = "recipe-${var.name}"
  parent_image = var.ec2_base_image_ami
  tags = {
    DistributionConfigurationId = "${var.distribution_configuration_id}"
    Name = "${var.name}"
  }
  version = var.recipe_version
  working_directory = "/tmp"
}

resource "aws_imagebuilder_component" "install_dependencies_component" {
  version = var.recipe_version
  description = "Installs dependencies on EC2 image"
  name = "InstallDependencies-${local.stack_name}-${var.name}"
  platform = "Linux"
  supported_os_versions = [
    "Fedora"
  ]
  data = ""
}

