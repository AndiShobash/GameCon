function confirmDelete() {
    return confirm('Are you sure you want to delete this game? This action cannot be undone.');
}

document.addEventListener('DOMContentLoaded', function() {
    const deleteForms = document.querySelectorAll('form[action$="/delete"]');
    deleteForms.forEach(form => {
        form.addEventListener('submit', function(event) {
            if (!confirmDelete()) {
                event.preventDefault();
            }
        });
    });
});
 