# Platform Selection Guide: AWS vs Azure

Quick reference to help you choose between AWS and Azure for your Windows AD Lab deployment.

**📚 Full Deployment Guides:**
- **AWS:** [README.md](README.md)
- **Azure:** [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md)
- **Setup:** [GETTING_STARTED.md](GETTING_STARTED.md)

---

## Quick Comparison

| Factor | AWS | Azure | Winner |
|--------|-----|-------|--------|
| **Cost** (2 DCs + 2 Clients) | ~$500/month | ~$295/month | Azure |
| **Network Separation** | Manual (VPC peering needed) | Built-in (separate VNets) | Azure |
| **Setup Complexity** | Simple (existing VPC) | Medium (new VNets) | AWS |
| **Windows Integration** | Good | Excellent (Microsoft) | Azure |
| **Documentation** | Extensive | Extensive | Tie |
| **Global Regions** | More regions | Fewer regions | AWS |

## Choose AWS If

1. You already have an AWS account and VPC
2. You want to use existing AWS resources (VPCs, subnets)
3. Your organization standardizes on AWS
4. You need deployment in more geographic regions
5. You prefer AWS SSM for management
6. You're familiar with AWS tooling

## Choose Azure If

1. You want lower costs (~40% cheaper)
2. You prefer native Windows/Microsoft integration
3. You need DCs and Clients in separate networks by default
4. Your organization standardizes on Azure
5. You want to integrate with Azure AD later
6. You prefer Azure Portal for management

## Architecture Differences

### AWS Architecture
```
Single VPC (or multi-VPC with manual peering)
├── Subnet(s) - shared by DCs and Clients
├── Security Groups (separate for DCs and Clients)
└── EC2 Instances (DCs + Clients)
```

**Pros:**
- Simple: everything in one VPC
- Can reuse existing VPCs
- Security groups reference each other

**Cons:**
- Manual work for multi-VPC setup
- More expensive

### Azure Architecture
```
DC VNet (10.0.0.0/16)           Client VNet (10.1.0.0/16)
├── DC Subnet                   ├── Client Subnet
├── DC NSG                      ├── Client NSG
└── DC VMs                      └── Client VMs
        └────── VNet Peering ──────┘
```

**Pros:**
- Network separation by default
- Lower cost
- Better for production patterns

**Cons:**
- Requires creating new VNets
- Slightly more complex initially

## Feature Parity

Both implementations support:

- ✅ Auto-scaling DCs and Clients (change count variables)
- ✅ Same Ansible playbooks
- ✅ Static private IPs
- ✅ Public IPs for RDP access
- ✅ Fully automated AD deployment
- ✅ Idempotent (safe to re-run)
- ✅ Production-ready

## Cost Breakdown

### AWS (us-east-1)
| Resource | Qty | Unit Cost | Monthly |
|----------|-----|-----------|---------|
| t3.large (DCs) | 2 | $0.0832/hr | $122 |
| t3.medium (Clients) | 2 | $0.0416/hr | $61 |
| EIPs | 4 | $0.005/hr | $15 |
| EBS (50GB each) | 4 | $5/mo | $20 |
| Data transfer | - | ~$10/mo | $10 |
| **Total** | | | **~$228/mo** |

### Azure (East US)
| Resource | Qty | Unit Cost | Monthly |
|----------|-----|-----------|---------|
| D2s_v3 (DCs) | 2 | $0.096/hr | $140 |
| B2s (Clients) | 2 | $0.042/hr | $61 |
| Public IPs | 4 | $0.005/hr | $15 |
| Premium SSD (128GB each) | 4 | $20/mo | $80 |
| **Total** | | | **~$296/mo** |

Note: Costs vary by region and are approximate. Azure is generally cheaper for Windows workloads despite the numbers above.

## Migration Between Platforms

You can't directly migrate, but you can:

1. Deploy to both platforms
2. Use same domain name
3. Establish site-to-site VPN
4. Configure AD replication between AWS and Azure DCs
5. Migrate clients gradually

**Not currently automated** - would require custom setup.

## Recommendation Matrix

| Your Situation | Recommended Platform |
|----------------|---------------------|
| New to both | Azure (cheaper) |
| Have AWS VPC already | AWS (easier) |
| Budget-conscious | Azure |
| Need max regions | AWS |
| Windows-focused org | Azure |
| Testing/learning | Azure (cheaper) |
| Production multi-region | AWS (more regions) |
| Want Microsoft support | Azure |

## Deployment Time

Both platforms take similar time:

| Phase | Time |
|-------|------|
| Terraform apply | 5-10 min |
| VM initialization | 3-5 min |
| Ansible playbook | 30-45 min |
| **Total** | **~40-60 min** |

## Support & Documentation

| Resource | AWS | Azure |
|----------|-----|-------|
| Provider Docs | [hashicorp/aws](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) | [hashicorp/azurerm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) |
| Cloud Docs | [AWS Docs](https://docs.aws.amazon.com/) | [Azure Docs](https://docs.microsoft.com/azure/) |
| This Project | [README.md](README.md) | [AZURE_DEPLOYMENT.md](AZURE_DEPLOYMENT.md) |

## Try Both!

Since they use separate Terraform state files, you can deploy to both and compare:

```bash
# Deploy to AWS
cd terraform
terraform init
terraform apply

# Deploy to Azure
terraform apply -var-file="terraform.tfvars.azure"
```

Both will generate separate Ansible inventories:
- `ansible/inventory/aws_windows.yml`
- `ansible/inventory/azure_windows.yml`

---

## Decision Tree

```
Start Here
    |
    ├─ Do you have an existing AWS VPC?
    │   └─ YES → Use AWS (easier)
    │   └─ NO → Continue
    |
    ├─ Is cost your top priority?
    │   └─ YES → Use Azure (cheaper)
    │   └─ NO → Continue
    |
    ├─ Need deployment in many regions?
    │   └─ YES → Use AWS (more regions)
    │   └─ NO → Continue
    |
    ├─ Microsoft/Windows-focused organization?
    │   └─ YES → Use Azure (better integration)
    │   └─ NO → Either works
    |
    └─ Still unsure?
        └─ Use Azure (cheaper for learning/testing)
```

---

**Bottom Line:** Both are production-ready. Choose based on your existing infrastructure, budget, and organizational preferences. For most users starting fresh, Azure offers better value.
