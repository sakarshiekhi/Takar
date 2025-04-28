from django.urls import path
from .views import RegisterView, ForgotPasswordView, ResetPasswordView, VerifyCodeView, EmailTokenObtainPairView

urlpatterns = [
    path('signup/', RegisterView.as_view(), name='signup'),
    path('login/', EmailTokenObtainPairView.as_view(), name='login'),  # Use EmailTokenObtainPairView for email-based login
    path('forgot-password/', ForgotPasswordView.as_view(), name='forgot-password'),
    path('verify-code/', VerifyCodeView.as_view(), name='verify-code'),
    path('reset-password/', ResetPasswordView.as_view(), name='reset-password'),
]
