# Host Your CV on AWS - Lab 7

**Student:** Zain Allaudin  
**Roll number:** 23L-3036  
**Course:** DevOps

## Architecture

```text
Browser --HTTP-> EC2 (Nginx) --IAM role --> Private S3 bucket/site/*
Browser --HTTPS-> Lambda Function URL --IAM role--> Private S3 bucket/site/*
                                              S3 Block Public Access: ON
```

For the EC2 path, a browser requests the public IPv4 address and Nginx serves the synchronized files from its web root. The EC2 instance role permits the sync script to read only objects under `site/` and list that prefix.

For the Lambda path, a browser requests the public Lambda Function URL. The function reads the requested object from private S3 using its execution role, substitutes the footer placeholder for the HTML page, and returns the correct content type.

## Resources

| Resource                 | Value                                                                      |
| ------------------------ | -------------------------------------------------------------------------- |
| AWS Region               | ap-southeast-2                                                             |
| S3 bucket                | cv-23l-3036                                                                |
| EC2 public IPv4          | 52.65.28.28                                                                |
| EC2 instance ID          | i-0de784cb185cc9585                                                        |
| Lambda function URL      | https://maewsnudthpv5sjwhgphb3ixdq0ktirr.lambda-url.ap-southeast-2.on.aws/ |
| Public GitHub repository | https://github.com/MianZainAllaudin/aws-cv-lab7                            |

## Security test: direct S3 access

```bash
curl -i "https://cv-23l-3036.s3.ap-southeast-2.amazonaws.com/site/index.html"
```

Keys are not pasted on purpose
Output:-
<Error>
<Code>AccessDenied</Code>
<Message>Access Denied</Message>
</Error>

## EC2 sync log

Paste the actual last 10 lines from the instance:

```bash
sudo tail -n 10 /var/log/cv-sync.log
```

Output:-
2026-10-23T20:41:38+00:00 status=success instance=i-0de784cb185cc9585
2026-10-23T20:47:08+00:00 status=success instance=i-0de784cb185cc9585
2026-10-23T20:52:08+00:00 status=success instance=i-0de784cb185cc9585
2026-10-23T20:57:38+00:00 status=success instance=i-0de784cb185cc9585
2026-10-23T21:03:08+00:00 status=success instance=i-0de784cb185cc9585
2026-10-23T21:08:08+00:00 status=success instance=i-0de784cb185cc9585
2026-10-23T21:13:38+00:00 status=success instance=i-0de784cb185cc9585
2026-10-23T21:19:08+00:00 status=success instance=i-0de784cb185cc9585
2026-10-23T21:24:08+00:00 status=success instance=i-0de784cb185cc9585
2026-10-23T21:29:38+00:00 status=success instance=i-0de784cb185cc9585

## Written answers

1. **Why use roles instead of access keys? What could go wrong if keys were in user data?**  
   Roles provide temporary credentials through AWS-managed credential delivery and avoid storing long-lived access keys in scripts. User data can be visible to users with instance access and may be copied into logs or repositories. A leaked key could let another person use the permissions until it is revoked.

2. **What happens when someone opens the S3 address of index.html directly, and which setting causes it?**  
   The request should be denied with HTTP 403 because the bucket is private and all four S3 Block Public Access settings are enabled. The public website is served through EC2 or Lambda, whose roles are allowed to read the required objects.

3. **Explain the public function URL permission. Why is that acceptable for Lambda but not for the bucket?**  
   The Lambda function URL uses authentication type NONE and a resource-based permission allowing public invocation. This is acceptable for this assignment because the function is intentionally a public CV website and it exposes only the requested site content. The bucket must remain private so visitors cannot bypass the two application paths or read objects directly.

4. **Compare the two paths. What costs occur with no visitors, and what happens if traffic grows 100 times?**  
   EC2 can incur instance and storage charges while running even if nobody visits. Lambda generally charges based on requests and execution, plus related logging and data transfer, so idle compute cost is usually lower. At much higher traffic, Lambda can scale invocation capacity automatically within service limits, while a single EC2 instance has finite capacity and may become a bottleneck. Actual cost depends on region, usage, and account offers.

5. **If the EC2 instance is deleted, what is lost and what remains?**  
   The running server, its public IPv4 address, and any data stored only on its instance storage are lost. The private S3 bucket, Lambda function, IAM roles, and GitHub repository remain unless they are separately deleted. The EC2 website will stop working until another server is deployed.
