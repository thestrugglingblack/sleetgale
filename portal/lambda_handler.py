"""
SageMaker Studio Portal - Lambda Handler
Serverless alternative to ECS for cost optimization
"""

import json
import boto3
import os
from urllib.parse import parse_qs

# Configuration from environment variables
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
SAGEMAKER_DOMAIN_ID = os.environ.get('SAGEMAKER_DOMAIN_ID', '')
DEFAULT_USER_PROFILE = os.environ.get('DEFAULT_USER_PROFILE', 'default-user')
SESSION_DURATION = int(os.environ.get('SESSION_DURATION', '43200'))  # 12 hours

# Initialize SageMaker client
sagemaker = boto3.client('sagemaker', region_name=AWS_REGION)

# HTML template for the portal
HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SageMaker Studio Portal</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            padding: 40px;
            max-width: 500px;
            width: 100%;
            text-align: center;
        }
        h1 { color: #333; margin-bottom: 10px; font-size: 28px; }
        .subtitle { color: #666; margin-bottom: 30px; font-size: 14px; }
        .info-box {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 30px;
            text-align: left;
        }
        .info-item { margin-bottom: 10px; font-size: 14px; }
        .info-label {
            color: #666;
            font-weight: 600;
            display: inline-block;
            min-width: 100px;
        }
        .info-value { color: #333; }
        .launch-button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 15px 40px;
            font-size: 16px;
            border-radius: 8px;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
            width: 100%;
            font-weight: 600;
        }
        .launch-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
        }
        .launch-button:disabled { opacity: 0.6; cursor: not-allowed; }
        .status { margin-top: 20px; padding: 10px; border-radius: 6px; font-size: 14px; }
        .status.loading { background: #e3f2fd; color: #1976d2; }
        .status.error { background: #ffebee; color: #c62828; }
        .footer { margin-top: 30px; color: #999; font-size: 12px; }
        .spinner {
            display: inline-block;
            width: 14px;
            height: 14px;
            border: 2px solid #1976d2;
            border-radius: 50%;
            border-top-color: transparent;
            animation: spin 1s linear infinite;
            margin-right: 8px;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        .icon { font-size: 48px; margin-bottom: 20px; }
        .badge {
            display: inline-block;
            background: #4caf50;
            color: white;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 600;
            margin-bottom: 15px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="badge">⚡ SERVERLESS</div>
        <div class="icon">🚀</div>
        <h1>SageMaker Studio Portal</h1>
        <p class="subtitle">Access your data science workspace</p>
        
        <div class="info-box">
            <div class="info-item">
                <span class="info-label">Domain:</span>
                <span class="info-value">{domain_id}</span>
            </div>
            <div class="info-item">
                <span class="info-label">Region:</span>
                <span class="info-value">{region}</span>
            </div>
            <div class="info-item">
                <span class="info-label">User Profile:</span>
                <span class="info-value">{user_profile}</span>
            </div>
        </div>
        
        <button class="launch-button" onclick="launchStudio()" id="launchBtn">
            Launch SageMaker Studio
        </button>
        
        <div id="status"></div>
        
        <div class="footer">
            Presigned URLs are valid for 12 hours<br>
            Powered by AWS Lambda (serverless)
        </div>
    </div>
    
    <script>
        async function launchStudio() {{
            const btn = document.getElementById('launchBtn');
            const status = document.getElementById('status');
            
            btn.disabled = true;
            status.className = 'status loading';
            status.innerHTML = '<span class="spinner"></span>Generating presigned URL...';
            
            try {{
                const response = await fetch(window.location.pathname + '?action=launch', {{
                    method: 'POST',
                    headers: {{ 'Content-Type': 'application/json' }}
                }});
                
                const data = await response.json();
                
                if (response.ok && data.url) {{
                    status.innerHTML = '<span class="spinner"></span>Redirecting to SageMaker Studio...';
                    window.location.href = data.url;
                }} else {{
                    throw new Error(data.error || 'Failed to generate URL');
                }}
            }} catch (error) {{
                status.className = 'status error';
                status.innerHTML = '❌ Error: ' + error.message;
                btn.disabled = false;
            }}
        }}
    </script>
</body>
</html>"""


def lambda_handler(event, context):
    """
    Lambda handler for SageMaker Studio portal
    Supports both ALB and direct invocation
    """
    
    # Determine request type (ALB or API Gateway/Function URL)
    request_context = event.get('requestContext', {})
    is_alb = 'elb' in request_context
    
    # Extract HTTP method and path
    http_method = event.get('httpMethod', event.get('requestContext', {}).get('http', {}).get('method', 'GET'))
    path = event.get('path', '/')
    query_params = event.get('queryStringParameters') or {}
    
    # Health check endpoint
    if path == '/health' or query_params.get('action') == 'health':
        return response(200, {'status': 'healthy'}, is_alb)
    
    # Launch endpoint - generate presigned URL
    if http_method == 'POST' or query_params.get('action') == 'launch':
        try:
            # Generate presigned URL
            presigned_response = sagemaker.create_presigned_domain_url(
                DomainId=SAGEMAKER_DOMAIN_ID,
                UserProfileName=DEFAULT_USER_PROFILE,
                SessionExpirationDurationInSeconds=SESSION_DURATION
            )
            
            authorized_url = presigned_response.get('AuthorizedUrl')
            
            if not authorized_url:
                raise Exception("Failed to generate presigned URL")
            
            return response(200, {'url': authorized_url}, is_alb)
            
        except Exception as e:
            print(f"Error generating presigned URL: {str(e)}")
            return response(500, {'error': str(e)}, is_alb)
    
    # Default: serve HTML portal page
    html = HTML_TEMPLATE.format(
        domain_id=SAGEMAKER_DOMAIN_ID,
        region=AWS_REGION,
        user_profile=DEFAULT_USER_PROFILE
    )
    
    return {
        'statusCode': 200,
        'statusDescription': '200 OK',
        'isBase64Encoded': False,
        'headers': {
            'Content-Type': 'text/html; charset=utf-8',
            'Cache-Control': 'no-cache'
        },
        'body': html
    }


def response(status_code, body, is_alb=False):
    """
    Create response in format expected by ALB or API Gateway
    """
    response_body = json.dumps(body) if isinstance(body, dict) else body
    
    base_response = {
        'statusCode': status_code,
        'isBase64Encoded': False,
        'headers': {
            'Content-Type': 'application/json',
            'Cache-Control': 'no-cache'
        },
        'body': response_body
    }
    
    # ALB requires statusDescription
    if is_alb:
        base_response['statusDescription'] = f'{status_code} {"OK" if status_code == 200 else "Error"}'
    
    return base_response
