import os
import boto3
from botocore.exceptions import ClientError
import uuid
from typing import Optional, BinaryIO
import streamlit as st
from datetime import datetime, timedelta

# Initialize S3 client (if AWS credentials are available)
def get_s3_client():
    """Get S3 client with credentials from environment"""
    try:
        return boto3.client(
            's3',
            aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
            aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY')
        )
    except:
        return None

def upload_to_s3(file_data: BinaryIO, file_extension: str, folder: str = 'uploads') -> Optional[str]:
    """Upload file to S3 and return URL"""
    s3_client = get_s3_client()
    if not s3_client:
        # Fallback to local storage simulation
        return upload_to_local(file_data, file_extension, folder)
    
    bucket_name = os.getenv('S3_BUCKET_NAME', 'snapchef-uploads')
    
    # Generate unique filename
    file_id = str(uuid.uuid4())
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"{folder}/{timestamp}_{file_id}.{file_extension}"
    
    try:
        # Upload file
        s3_client.put_object(
            Bucket=bucket_name,
            Key=filename,
            Body=file_data,
            ContentType=get_content_type(file_extension)
        )
        
        # Generate URL
        url = f"https://{bucket_name}.s3.amazonaws.com/{filename}"
        return url
        
    except ClientError as e:
        st.error(f"Upload failed: {str(e)}")
        return None

def upload_to_local(file_data: BinaryIO, file_extension: str, folder: str = 'uploads') -> str:
    """Simulate file upload for local development"""
    # Create uploads directory if it doesn't exist
    upload_dir = os.path.join(os.getcwd(), 'uploads', folder)
    os.makedirs(upload_dir, exist_ok=True)
    
    # Generate unique filename
    file_id = str(uuid.uuid4())
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"{timestamp}_{file_id}.{file_extension}"
    filepath = os.path.join(upload_dir, filename)
    
    # Save file locally
    with open(filepath, 'wb') as f:
        f.write(file_data.read())
    
    # Return mock URL
    return f"/uploads/{folder}/{filename}"

def get_signed_url(file_key: str, expiration: int = 3600) -> Optional[str]:
    """Generate a signed URL for secure file access"""
    s3_client = get_s3_client()
    if not s3_client:
        return file_key  # Return as-is for local development
    
    bucket_name = os.getenv('S3_BUCKET_NAME', 'snapchef-uploads')
    
    try:
        url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': bucket_name, 'Key': file_key},
            ExpiresIn=expiration
        )
        return url
    except ClientError:
        return None

def delete_from_s3(file_key: str) -> bool:
    """Delete file from S3"""
    s3_client = get_s3_client()
    if not s3_client:
        return delete_from_local(file_key)
    
    bucket_name = os.getenv('S3_BUCKET_NAME', 'snapchef-uploads')
    
    try:
        s3_client.delete_object(Bucket=bucket_name, Key=file_key)
        return True
    except ClientError:
        return False

def delete_from_local(filepath: str) -> bool:
    """Delete file from local storage"""
    try:
        if os.path.exists(filepath):
            os.remove(filepath)
        return True
    except:
        return False

def get_content_type(file_extension: str) -> str:
    """Get content type based on file extension"""
    content_types = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'gif': 'image/gif',
        'mp4': 'video/mp4',
        'mov': 'video/quicktime',
        'avi': 'video/x-msvideo',
        'webm': 'video/webm'
    }
    
    return content_types.get(file_extension.lower(), 'application/octet-stream')

def process_uploaded_image(uploaded_file) -> Optional[str]:
    """Process and store uploaded image"""
    if uploaded_file is None:
        return None
    
    # Get file extension
    file_extension = uploaded_file.name.split('.')[-1].lower()
    
    # Validate file type
    allowed_extensions = ['jpg', 'jpeg', 'png', 'gif']
    if file_extension not in allowed_extensions:
        st.error(f"Invalid file type. Allowed types: {', '.join(allowed_extensions)}")
        return None
    
    # Check file size (max 10MB)
    file_size = len(uploaded_file.getvalue())
    max_size = 10 * 1024 * 1024  # 10MB
    
    if file_size > max_size:
        st.error("File too large. Maximum size is 10MB.")
        return None
    
    # Upload to storage
    file_url = upload_to_s3(uploaded_file, file_extension, 'recipe_photos')
    
    if file_url:
        # Track upload in session
        if 'uploaded_images' not in st.session_state:
            st.session_state.uploaded_images = []
        
        st.session_state.uploaded_images.append({
            'url': file_url,
            'timestamp': datetime.now(),
            'size': file_size
        })
    
    return file_url

def process_uploaded_video(uploaded_file) -> Optional[str]:
    """Process and store uploaded video"""
    if uploaded_file is None:
        return None
    
    # Get file extension
    file_extension = uploaded_file.name.split('.')[-1].lower()
    
    # Validate file type
    allowed_extensions = ['mp4', 'mov', 'avi', 'webm']
    if file_extension not in allowed_extensions:
        st.error(f"Invalid file type. Allowed types: {', '.join(allowed_extensions)}")
        return None
    
    # Check file size (max 50MB)
    file_size = len(uploaded_file.getvalue())
    max_size = 50 * 1024 * 1024  # 50MB
    
    if file_size > max_size:
        st.error("File too large. Maximum size is 50MB.")
        return None
    
    # Upload to storage
    file_url = upload_to_s3(uploaded_file, file_extension, 'recipe_videos')
    
    if file_url:
        # Track upload in session
        if 'uploaded_videos' not in st.session_state:
            st.session_state.uploaded_videos = []
        
        st.session_state.uploaded_videos.append({
            'url': file_url,
            'timestamp': datetime.now(),
            'size': file_size,
            'duration': None  # Could extract with ffmpeg
        })
    
    return file_url

def cleanup_old_uploads(days_old: int = 7):
    """Clean up old temporary uploads"""
    # In production, this would be a scheduled job
    # For now, just track in session
    if 'uploaded_images' in st.session_state:
        cutoff_date = datetime.now() - timedelta(days=days_old)
        
        # Filter out old uploads
        st.session_state.uploaded_images = [
            upload for upload in st.session_state.uploaded_images
            if upload['timestamp'] > cutoff_date
        ]

def get_storage_usage() -> Dict:
    """Get current storage usage for user"""
    total_size = 0
    file_count = 0
    
    # Calculate from session state
    if 'uploaded_images' in st.session_state:
        for upload in st.session_state.uploaded_images:
            total_size += upload.get('size', 0)
            file_count += 1
    
    if 'uploaded_videos' in st.session_state:
        for upload in st.session_state.uploaded_videos:
            total_size += upload.get('size', 0)
            file_count += 1
    
    return {
        'total_size_mb': round(total_size / (1024 * 1024), 2),
        'file_count': file_count,
        'limit_mb': 100,  # Free tier limit
        'usage_percent': min(100, (total_size / (100 * 1024 * 1024)) * 100)
    }

# Firebase Storage Alternative (if using Firebase instead of S3)
def init_firebase_storage():
    """Initialize Firebase Storage"""
    # This would be implemented if using Firebase
    # import firebase_admin
    # from firebase_admin import credentials, storage
    pass

# Cloudinary Alternative (for image optimization)
def upload_to_cloudinary(file_data: BinaryIO, file_type: str) -> Optional[str]:
    """Upload to Cloudinary for automatic optimization"""
    # This would be implemented if using Cloudinary
    # import cloudinary
    # import cloudinary.uploader
    pass