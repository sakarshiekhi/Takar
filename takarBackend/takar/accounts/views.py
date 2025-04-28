import random
import string
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .register_serializer import RegisterSerializer
from django.core.mail import send_mail
from django.contrib.auth import get_user_model
from .models import PasswordResetCode
from django.utils import timezone
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.conf import settings
from django.contrib.auth import get_user_model

User = get_user_model()

# REGISTER VIEW
class RegisterView(APIView):
    def post(self, request):
        print('DEBUG: Starting registration process')
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            print('DEBUG: User registered successfully')
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        print(f'DEBUG: Registration failed - {serializer.errors}')
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

# CUSTOM LOGIN VIEW USING EMAIL
class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = User.EMAIL_FIELD

    def validate(self, attrs):
        # Use email as the login field (maps email to username)
        attrs['username'] = attrs.get('email')
        return super().validate(attrs)

class EmailTokenObtainPairView(TokenObtainPairView):
    serializer_class = EmailTokenObtainPairSerializer


# Send code
class ForgotPasswordView(APIView):
    def post(self, request):
        print('DEBUG: Starting password reset process')
        email = request.data.get('email')
        print(f'DEBUG: Attempting reset for email: {email}')
        
        try:
            print('DEBUG: Looking for user with email:', email)
            user = User.objects.filter(email=email).first()
            
            if not user:
                print('DEBUG: No user found with email:', email)
                return Response({"error": "User with this email does not exist."}, status=404)
            
            print('DEBUG: Found user:', user.email)
            
            # Generate code
            code = ''.join(random.choices(string.digits, k=6))
            print('DEBUG: Generated reset code:', code)
            
            # Save code
            reset_code = PasswordResetCode.objects.create(
                user=user,
                code=code
            )
            print('DEBUG: Saved reset code to database')
            
            try:
                # Send email
                send_mail(
                    'Password Reset Code',
                    f'Your password reset code is: {code}',
                    'noreply@takarapp.com',
                    [email],
                    fail_silently=False,
                )
                print('DEBUG: Reset code email sent successfully')
                return Response({"message": "Reset code sent to your email."})
            except Exception as e:
                print('DEBUG: Email sending failed:', str(e))
                return Response({"error": "Failed to send email"}, status=500)
                
        except Exception as e:
            print('DEBUG: Error in password reset:', str(e))
            return Response({"error": str(e)}, status=500)


# Verify code
class VerifyCodeView(APIView):
    def post(self, request):
        email = request.data.get('email')
        code = request.data.get('code')

        try:
            user = User.objects.get(email=email)
            reset_entry = PasswordResetCode.objects.filter(user=user, code=code).last()

            if reset_entry and not reset_entry.is_expired():
                return Response({"message": "Code verified successfully."})
            else:
                return Response({"error": "Invalid or expired code."}, status=400)

        except User.DoesNotExist:
            return Response({"error": "User with this email does not exist."}, status=404)

# Reset password
class ResetPasswordView(APIView):
    def post(self, request):
        email = request.data.get('email')
        code = request.data.get('code')
        new_password = request.data.get('new_password')

        try:
            user = User.objects.get(email=email)
            reset_entry = PasswordResetCode.objects.filter(user=user, code=code).last()

            if reset_entry and not reset_entry.is_expired():
                user.set_password(new_password)
                user.save()
                reset_entry.delete()  # remove used code
                return Response({"message": "Password has been reset."})
            else:
                return Response({"error": "Invalid or expired code."}, status=400)

        except User.DoesNotExist:
            return Response({"error": "User with this email does not exist."}, status=404)
