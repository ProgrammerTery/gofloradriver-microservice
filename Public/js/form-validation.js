/* Form Validation and Utility JavaScript */
window.FormValidation = {
    // Email validation
    validateEmail: function(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    },

    // Password validation
    validatePassword: function(password, minLength = 8) {
        return password.length >= minLength;
    },

    // Phone validation
    validatePhone: function(phone) {
        const phoneRegex = /^[\+]?[1-9][\d]{0,15}$/;
        return phoneRegex.test(phone.replace(/[\s\-\(\)]/g, ''));
    },

    // Driver ID validation
    validateDriverID: function(driverID) {
        const driverIDRegex = /^[A-Za-z0-9_-]+$/;
        return driverIDRegex.test(driverID) && driverID.length >= 3;
    },

    // Vehicle year validation
    validateVehicleYear: function(year) {
        const currentYear = new Date().getFullYear();
        return year >= 2015 && year <= currentYear + 1;
    },

    // Real-time validation setup
    setupRealTimeValidation: function() {
        // Email validation
        const emailInputs = document.querySelectorAll('input[type="email"]');
        emailInputs.forEach(input => {
            input.addEventListener('blur', function() {
                if (this.value && !FormValidation.validateEmail(this.value)) {
                    this.setCustomValidity('Please enter a valid email address');
                } else {
                    this.setCustomValidity('');
                }
            });
        });

        // Password validation
        const passwordInputs = document.querySelectorAll('input[type="password"]');
        passwordInputs.forEach(input => {
            if (input.id === 'password') {
                input.addEventListener('input', function() {
                    const isValid = FormValidation.validatePassword(this.value);
                    const requirements = this.parentNode.querySelector('.password-requirements');
                    if (requirements) {
                        requirements.style.color = isValid ? '#10b981' : '#ef4444';
                    }
                });
            }
        });

        // Driver ID validation
        const driverIDInput = document.getElementById('driverID');
        if (driverIDInput) {
            driverIDInput.addEventListener('input', function() {
                // Convert to valid format
                this.value = this.value.replace(/[^A-Za-z0-9_-]/g, '');
                
                const isValid = FormValidation.validateDriverID(this.value);
                if (this.value.length > 0 && !isValid) {
                    this.setCustomValidity('Driver ID must be at least 3 characters and contain only letters, numbers, underscores, and hyphens');
                } else {
                    this.setCustomValidity('');
                }
            });
        }

        // Phone number formatting
        const phoneInputs = document.querySelectorAll('input[type="tel"]');
        phoneInputs.forEach(input => {
            input.addEventListener('input', function() {
                // Basic phone formatting for US numbers
                let value = this.value.replace(/\D/g, '');
                if (value.length >= 10) {
                    value = value.substring(0, 10);
                    this.value = `(${value.substring(0, 3)}) ${value.substring(3, 6)}-${value.substring(6)}`;
                }
            });
        });

        // Vehicle year validation
        const yearInput = document.getElementById('year');
        if (yearInput) {
            yearInput.addEventListener('blur', function() {
                const year = parseInt(this.value);
                if (year && !FormValidation.validateVehicleYear(year)) {
                    this.setCustomValidity('Vehicle must be 2015 or newer');
                } else {
                    this.setCustomValidity('');
                }
            });
        }
    }
};

// Form submission utilities
window.FormUtils = {
    // Show loading state
    showLoading: function(form, buttonSelector = 'button[type="submit"]') {
        const button = form.querySelector(buttonSelector);
        if (button) {
            button.disabled = true;
            button.dataset.originalText = button.textContent;
            button.innerHTML = '<span class="spinner" style="width: 16px; height: 16px; margin-right: 8px;"></span>Loading...';
        }
        
        // Show overlay if available
        const overlay = document.getElementById('loadingOverlay');
        if (overlay) {
            overlay.style.display = 'flex';
        }
    },

    // Hide loading state
    hideLoading: function(form, buttonSelector = 'button[type="submit"]') {
        const button = form.querySelector(buttonSelector);
        if (button && button.dataset.originalText) {
            button.disabled = false;
            button.textContent = button.dataset.originalText;
        }
        
        // Hide overlay if available
        const overlay = document.getElementById('loadingOverlay');
        if (overlay) {
            overlay.style.display = 'none';
        }
    },

    // Validate form before submission
    validateForm: function(form) {
        const inputs = form.querySelectorAll('input[required], textarea[required], select[required]');
        let isValid = true;
        let firstInvalidInput = null;

        inputs.forEach(input => {
            if (!input.value.trim()) {
                isValid = false;
                input.setCustomValidity('This field is required');
                if (!firstInvalidInput) {
                    firstInvalidInput = input;
                }
            } else {
                input.setCustomValidity('');
            }
        });

        // Additional validation based on input type
        const emailInputs = form.querySelectorAll('input[type="email"]');
        emailInputs.forEach(input => {
            if (input.value && !FormValidation.validateEmail(input.value)) {
                isValid = false;
                input.setCustomValidity('Please enter a valid email address');
                if (!firstInvalidInput) {
                    firstInvalidInput = input;
                }
            }
        });

        // Password confirmation validation
        const password = form.querySelector('#password');
        const confirmPassword = form.querySelector('#confirmPassword');
        if (password && confirmPassword && password.value !== confirmPassword.value) {
            isValid = false;
            confirmPassword.setCustomValidity('Passwords do not match');
            if (!firstInvalidInput) {
                firstInvalidInput = confirmPassword;
            }
        }

        // Focus on first invalid input
        if (!isValid && firstInvalidInput) {
            firstInvalidInput.focus();
            firstInvalidInput.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }

        return isValid;
    }
};

// Notification system
window.NotificationSystem = {
    show: function(message, type = 'success', duration = 5000) {
        const container = document.getElementById('notifications');
        if (!container) return;

        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.innerHTML = `
            <span>${message}</span>
            <button onclick="this.parentElement.remove()" aria-label="Close notification">&times;</button>
        `;
        
        container.appendChild(notification);

        // Auto remove after duration
        setTimeout(() => {
            if (notification.parentElement) {
                notification.style.opacity = '0';
                setTimeout(() => notification.remove(), 300);
            }
        }, duration);
    },

    error: function(message, duration = 7000) {
        this.show(message, 'error', duration);
    },

    success: function(message, duration = 5000) {
        this.show(message, 'success', duration);
    }
};

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    // Setup real-time validation
    FormValidation.setupRealTimeValidation();

    // Setup form submissions
    const forms = document.querySelectorAll('form');
    forms.forEach(form => {
        form.addEventListener('submit', function(e) {
            if (!FormUtils.validateForm(form)) {
                e.preventDefault();
                NotificationSystem.error('Please correct the errors in the form before submitting.');
                return false;
            }

            // Show loading for forms that don't have their own handlers
            if (!form.dataset.noAutoLoading) {
                FormUtils.showLoading(form);
                
                // Hide loading after a delay if form doesn't submit
                setTimeout(() => {
                    FormUtils.hideLoading(form);
                }, 10000);
            }
        });
    });

    // Auto-focus first input in forms
    const firstInput = document.querySelector('.auth-form input, .vehicle-form input');
    if (firstInput) {
        firstInput.focus();
    }

    // Setup password confirmation real-time validation
    const confirmPassword = document.getElementById('confirmPassword');
    const password = document.getElementById('password');
    if (confirmPassword && password) {
        confirmPassword.addEventListener('input', function() {
            if (this.value !== password.value) {
                this.setCustomValidity('Passwords do not match');
            } else {
                this.setCustomValidity('');
            }
        });
    }

    // License plate auto-uppercase
    const licensePlateInput = document.getElementById('licensePlate');
    if (licensePlateInput) {
        licensePlateInput.addEventListener('input', function() {
            this.value = this.value.toUpperCase().replace(/[^A-Z0-9-]/g, '');
        });
    }
});

// Export for global use
window.FormValidation = FormValidation;
window.FormUtils = FormUtils;
window.NotificationSystem = NotificationSystem;