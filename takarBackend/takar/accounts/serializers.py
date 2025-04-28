from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.views import TokenObtainPairView
from django.contrib.auth.models import User
from rest_framework import serializers

class MyTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = User.EMAIL_FIELD

    def validate(self, attrs):
        credentials = {
            'email': attrs.get("email"),
            'password': attrs.get("password")
        }

        user = User.objects.filter(email=credentials['email']).first()
        if user is None or not user.check_password(credentials['password']):
            raise serializers.ValidationError("Invalid email or password")

        data = super().validate({
            'username': user.username,
            'password': credentials['password']
        })
        return data
