//Codigo para efecto de tipeo del header

document.addEventListener("DOMContentLoaded", function() {
  const textElement = document.getElementById("typing-text");
  // Si el elemento con el ID "typing-text" no existe, no hacemos nada.
  if (!textElement) return;
  
  const text = "Encontrá a profesionales de forma rápida y eficiente";
  let i = 0;
  const speed = 50; // Velocidad del tipeo en milisegundos

  // Limpiamos el contenido del elemento antes de empezar
  textElement.textContent = '';

  function typeWriter() {
    if (i < text.length) {
      textElement.textContent += text.charAt(i);
      i++;
      setTimeout(typeWriter, speed);
    }
  }

  typeWriter();
});