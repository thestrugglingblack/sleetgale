"""
SageMaker Studio Portal
A simple web portal that generates presigned URLs for SageMaker Studio access
"""

from flask import Flask, redirect, render_template_string, request, jsonify
import boto3
import os
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration from environment variables
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
SAGEMAKER_DOMAIN_ID = os.environ.get('SAGEMAKER_DOMAIN_ID', '')
DEFAULT_USER_PROFILE = os.environ.get('DEFAULT_USER_PROFILE', 'default-user')
SESSION_DURATION = int(os.environ.get('SESSION_DURATION', '43200'))  # 12 hours default

# Initialize SageMaker client
sagemaker = boto3.client('sagemaker', region_name=AWS_REGION)

# HTML template for the portal
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SageMaker Studio Portal</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
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
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 28px;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 14px;
        }
        .info-box {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 30px;
            text-align: left;
        }
        .info-item {
            margin-bottom: 10px;
            font-size: 14px;
        }
        .info-label {
            color: #666;
            font-weight: 600;
            display: inline-block;
            min-width: 100px;
        }
        .info-value {
            color: #333;
        }
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
        .launch-button:active {
            transform: translateY(0);
        }
        .launch-button:disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }
        .status {
            margin-top: 20px;
            padding: 10px;
            border-radius: 6px;
            font-size: 14px;
        }
        .status.loading {
            background: #e3f2fd;
            color: #1976d2;
        }
        .status.error {
            background: #ffebee;
            color: #c62828;
        }
        .footer {
            margin-top: 30px;
            color: #999;
            font-size: 12px;
        }
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
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        .icon {
            font-size: 48px;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">🚀</div>
        <h1>SageMaker Studio Portal</h1>
        <p class="subtitle">Access your data science workspace</p>
        
        <div class="info-box">
            <div class="info-item">
                <span class="info-label">Domain:</span>
                <span class="info-value">{{ domain_id }}</span>
            </div>
            <div class="info-item">
                <span class="info-label">Region:</span>
                <span class="info-value">{{ region }}</span>
            </div>
            <div class="info-item">
                <span class="info-label">User Profile:</span>
                <span class="info-value">{{ user_profile }}</span>
            </div>
        </div>
        
        <button class="launch-button" onclick="launchStudio()" id="launchBtn">
            Launch SageMaker Studio
        </button>
        
        <div id="status"></div>
        
        <div class="footer">
            Presigned URLs are valid for 12 hours<br>
            Powered by AWS SageMaker
        </div>
    </div>
    
    <script>
        async function launchStudio() {
            const btn = document.getElementById('launchBtn');
            const status = document.getElementById('status');
            
            btn.disabled = true;
            status.className = 'status loading';
            status.innerHTML = '<span class="spinner"></span>Generating presigned URL...';
            
            try {
                const response = await fetch('/launch', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    }
                });
                
                const data = await response.json();
                
                if (response.ok && data.url) {
                    status.innerHTML = '<span class="spinner"></span>Redirecting to SageMaker Studio...';
                    // Redirect to SageMaker Studio
                    window.location.href = data.url;
                } else {
                    throw new Error(data.error || 'Failed to generate URL');
                }
            } catch (error) {
                status.className = 'status error';
                status.innerHTML = '❌ Error: ' + error.message;
                btn.disabled = false;
            }
        }
    </script>
</body>
</html>
"""

@app.route('/')
def index():
    """Main portal page"""
    return render_template_string(
        HTML_TEMPLATE,
        domain_id=SAGEMAKER_DOMAIN_ID,
        region=AWS_REGION,
        user_profile=DEFAULT_USER_PROFILE
    )

@app.route('/health')
def health():
    """Health check endpoint for ALB"""
    return jsonify({'status': 'healthy'}), 200

@app.route('/launch', methods=['POST'])
def launch():
    """Generate presigned URL and redirect to SageMaker Studio"""
    try:
        # Get user profile from request or use default
        user_profile = request.json.get('user_profile', DEFAULT_USER_PROFILE) if request.json else DEFAULT_USER_PROFILE
        
        logger.info(f"Generating presigned URL for domain {SAGEMAKER_DOMAIN_ID}, user {user_profile}")
        
        # Generate presigned URL
        response = sagemaker.create_presigned_domain_url(
            DomainId=SAGEMAKER_DOMAIN_ID,
            UserProfileName=user_profile,
            SessionExpirationDurationInSeconds=SESSION_DURATION
        )
        
        authorized_url = response.get('AuthorizedUrl')
        
        if not authorized_url:
            raise Exception("Failed to generate presigned URL")
        
        logger.info("Presigned URL generated successfully")
        return jsonify({'url': authorized_url}), 200
        
    except Exception as e:
        logger.error(f"Error generating presigned URL: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/users')
def list_users():
    """List available user profiles (for debugging)"""
    try:
        response = sagemaker.list_user_profiles(DomainIdEquals=SAGEMAKER_DOMAIN_ID)
        users = [profile['UserProfileName'] for profile in response.get('UserProfiles', [])]
        return jsonify({'users': users}), 200
    except Exception as e:
        logger.error(f"Error listing users: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Validate configuration
    if not SAGEMAKER_DOMAIN_ID:
        logger.warning("SAGEMAKER_DOMAIN_ID not set. Portal will not function correctly.")
    
    # Run the app
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
