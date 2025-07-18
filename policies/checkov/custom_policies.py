"""
Custom Checkov Security Policies for Mobile Infrastructure
Used by mob-infra-cicd workflows

These policies extend the default Checkov checks with organization-specific
security requirements and best practices.
"""

from checkov.common.models.enums import TrueOrFalse, FALSE_POSITIVES
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
from checkov.common.models.consts import ANY_VALUE


class EightpointS3BucketNaming(BaseResourceCheck):
    """
    Ensure S3 buckets follow Eightpoint naming convention
    """
    def __init__(self):
        name = "Ensure S3 buckets follow Eightpoint naming convention"
        id = "CKV_EIGHTPOINT_001"
        supported_resources = ['aws_s3_bucket']
        categories = ['CONVENTION']
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        S3 buckets should follow pattern: {team}-{environment}-{purpose}
        Examples: ios-dev-terraform-state, android-prod-app-storage
        """
        bucket_name = conf.get('bucket')
        if bucket_name and isinstance(bucket_name, list):
            bucket_name = bucket_name[0]
        
        if bucket_name:
            # Valid patterns
            valid_prefixes = ['ios-', 'android-', 'shared-', 'mob-']
            valid_environments = ['-dev-', '-prod-', '-global-']
            
            # Check if bucket name starts with valid team prefix
            has_valid_prefix = any(bucket_name.startswith(prefix) for prefix in valid_prefixes)
            
            # Check if bucket name contains valid environment
            has_valid_env = any(env in bucket_name for env in valid_environments)
            
            if has_valid_prefix and has_valid_env:
                return CheckResult.PASSED
            else:
                return CheckResult.FAILED
        
        return CheckResult.FAILED


class EightpointResourceTagging(BaseResourceCheck):
    """
    Ensure resources have required Eightpoint tags
    """
    def __init__(self):
        name = "Ensure resources have required Eightpoint tags"
        id = "CKV_EIGHTPOINT_002"
        supported_resources = [
            'aws_instance', 'aws_s3_bucket', 'aws_rds_instance', 'aws_rds_cluster',
            'aws_eks_cluster', 'aws_elasticsearch_domain', 'aws_elasticache_cluster',
            'aws_lb', 'aws_nat_gateway', 'aws_vpc'
        ]
        categories = ['TAGGING']
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        Required tags: Team, Environment, Project, ManagedBy
        """
        tags = conf.get('tags')
        if not tags or not isinstance(tags, list):
            return CheckResult.FAILED
        
        tags_dict = tags[0] if tags else {}
        
        required_tags = ['Team', 'Environment', 'Project', 'ManagedBy']
        
        for required_tag in required_tags:
            if required_tag not in tags_dict:
                return CheckResult.FAILED
        
        # Validate Team values
        valid_teams = ['ios', 'android', 'shared']
        team_value = tags_dict.get('Team', '').lower()
        if team_value not in valid_teams:
            return CheckResult.FAILED
        
        # Validate Environment values
        valid_environments = ['dev', 'prod', 'global', 'test']
        env_value = tags_dict.get('Environment', '').lower()
        if env_value not in valid_environments:
            return CheckResult.FAILED
        
        # Validate ManagedBy
        managed_by = tags_dict.get('ManagedBy', '').lower()
        if managed_by != 'terraform':
            return CheckResult.FAILED
        
        return CheckResult.PASSED


class EightpointSecurityGroupNaming(BaseResourceCheck):
    """
    Ensure Security Groups follow naming convention
    """
    def __init__(self):
        name = "Ensure Security Groups follow Eightpoint naming convention"
        id = "CKV_EIGHTPOINT_003"
        supported_resources = ['aws_security_group']
        categories = ['CONVENTION']
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        Security Groups should follow pattern: {team}-{environment}-{service}-{purpose}
        Examples: ios-dev-eks-cluster, android-prod-rds-database
        """
        sg_name = conf.get('name')
        if sg_name and isinstance(sg_name, list):
            sg_name = sg_name[0]
        
        if sg_name:
            # Should have at least 4 parts separated by hyphens
            parts = sg_name.split('-')
            if len(parts) < 4:
                return CheckResult.FAILED
            
            # First part should be valid team
            if parts[0] not in ['ios', 'android', 'shared']:
                return CheckResult.FAILED
            
            # Second part should be valid environment
            if parts[1] not in ['dev', 'prod', 'global']:
                return CheckResult.FAILED
            
            return CheckResult.PASSED
        
        return CheckResult.FAILED


class EightpointIAMRoleNaming(BaseResourceCheck):
    """
    Ensure IAM Roles follow naming convention
    """
    def __init__(self):
        name = "Ensure IAM Roles follow Eightpoint naming convention"
        id = "CKV_EIGHTPOINT_004"
        supported_resources = ['aws_iam_role']
        categories = ['CONVENTION']
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        IAM Roles should follow pattern: {Team}-{Environment}-{Service}-{Purpose}
        Examples: iOS-Dev-EKS-NodeGroup, Android-Prod-Lambda-Execution
        """
        role_name = conf.get('name')
        if role_name and isinstance(role_name, list):
            role_name = role_name[0]
        
        if role_name:
            # Should have at least 4 parts separated by hyphens
            parts = role_name.split('-')
            if len(parts) < 4:
                return CheckResult.FAILED
            
            # First part should be valid team (case insensitive)
            if parts[0].lower() not in ['ios', 'android', 'shared']:
                return CheckResult.FAILED
            
            # Second part should be valid environment (case insensitive)
            if parts[1].lower() not in ['dev', 'prod', 'global']:
                return CheckResult.FAILED
            
            return CheckResult.PASSED
        
        return CheckResult.FAILED


class EightpointKMSKeyRotation(BaseResourceCheck):
    """
    Ensure KMS keys have automatic rotation enabled for production
    """
    def __init__(self):
        name = "Ensure KMS keys have automatic rotation enabled for production"
        id = "CKV_EIGHTPOINT_005"
        supported_resources = ['aws_kms_key']
        categories = ['ENCRYPTION']
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        KMS keys in production environments should have automatic rotation enabled
        """
        # Check if this is a production environment based on tags or description
        tags = conf.get('tags', [{}])
        tags_dict = tags[0] if tags else {}
        
        description = conf.get('description', [''])[0] if conf.get('description') else ''
        
        # Check if this is production environment
        is_prod = (
            tags_dict.get('Environment', '').lower() == 'prod' or
            'prod' in description.lower() or
            'production' in description.lower()
        )
        
        if is_prod:
            # For production, rotation must be enabled
            rotation_enabled = conf.get('enable_key_rotation')
            if rotation_enabled and isinstance(rotation_enabled, list):
                return CheckResult.PASSED if rotation_enabled[0] else CheckResult.FAILED
            return CheckResult.FAILED
        
        # For non-production environments, this check passes
        return CheckResult.PASSED


class EightpointRDSBackupRetention(BaseResourceCheck):
    """
    Ensure RDS instances have appropriate backup retention
    """
    def __init__(self):
        name = "Ensure RDS instances have appropriate backup retention periods"
        id = "CKV_EIGHTPOINT_006"
        supported_resources = ['aws_db_instance', 'aws_rds_cluster']
        categories = ['BACKUP']
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        Production: minimum 7 days backup retention
        Development: minimum 1 day backup retention
        """
        tags = conf.get('tags', [{}])
        tags_dict = tags[0] if tags else {}
        
        environment = tags_dict.get('Environment', '').lower()
        
        # Get backup retention period
        backup_retention = conf.get('backup_retention_period')
        if backup_retention and isinstance(backup_retention, list):
            retention_days = backup_retention[0]
            
            # Check minimum retention based on environment
            if environment == 'prod' or environment == 'production':
                return CheckResult.PASSED if retention_days >= 7 else CheckResult.FAILED
            else:
                return CheckResult.PASSED if retention_days >= 1 else CheckResult.FAILED
        
        return CheckResult.FAILED


class EightpointEKSEndpointAccess(BaseResourceCheck):
    """
    Ensure EKS clusters have appropriate endpoint access configuration
    """
    def __init__(self):
        name = "Ensure EKS clusters have secure endpoint access configuration"
        id = "CKV_EIGHTPOINT_007"
        supported_resources = ['aws_eks_cluster']
        categories = ['NETWORKING']
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        EKS clusters should have:
        - Private endpoint access enabled
        - Public endpoint access restricted to specific CIDRs (not 0.0.0.0/0)
        """
        vpc_config = conf.get('vpc_config')
        if not vpc_config or not isinstance(vpc_config, list):
            return CheckResult.FAILED
        
        vpc_config = vpc_config[0]
        
        # Check private endpoint access
        private_access = vpc_config.get('endpoint_private_access', [False])[0]
        if not private_access:
            return CheckResult.FAILED
        
        # Check public endpoint access configuration
        public_access = vpc_config.get('endpoint_public_access', [True])[0]
        if public_access:
            # If public access is enabled, check for CIDR restrictions
            public_cidrs = vpc_config.get('public_access_cidrs', [])
            if not public_cidrs or '0.0.0.0/0' in public_cidrs:
                return CheckResult.FAILED
        
        return CheckResult.PASSED


# Import CheckResult for the custom checks
try:
    from checkov.common.models.enums import CheckResult
except ImportError:
    # Fallback for older versions of Checkov
    class CheckResult:
        PASSED = "PASSED"
        FAILED = "FAILED"
        SKIPPED = "SKIPPED"
        UNKNOWN = "UNKNOWN"