from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils import timezone
from datetime import timedelta

class User(AbstractUser):
    email = models.EmailField(unique=True)
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']  # Email & password are required by default

    def __str__(self):
        return self.email

class PasswordResetCode(models.Model):
    user = models.ForeignKey('accounts.User', on_delete=models.CASCADE)  # Use string reference
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)

    def is_expired(self):
        # Code expires after 10 minutes
        return timezone.now() > self.created_at + timedelta(minutes=10)
