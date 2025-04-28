from django.contrib.auth import views as auth_views
from django.contrib import admin
from django.urls import path
from accounts.views import RegisterView, EmailTokenObtainPairView
from rest_framework_simplejwt.views import TokenRefreshView
from django.urls import path, include

urlpatterns = [
     #authentication endpoints
    path('admin/', admin.site.urls),
    path('api/signup/', RegisterView.as_view(), name='signup'),
    path('api/token/', EmailTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    


     # Password reset endpoints
    path('api/password-reset/', auth_views.PasswordResetView.as_view(), name='password_reset'),
    path('api/password-reset-done/', auth_views.PasswordResetDoneView.as_view(), name='password_reset_done'),
    path('api/password-reset-confirm/<uidb64>/<token>/', auth_views.PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
    path('api/password-reset-complete/', auth_views.PasswordResetCompleteView.as_view(), name='password_reset_complete'),
    path('api/', include('accounts.urls')),
]





