function createSnowflake() {
  const snowflake = document.createElement('span');
  snowflake.innerHTML = '❅';
  snowflake.style.position = 'absolute';
  snowflake.style.color = '#fff';
  snowflake.style.userSelect = 'none';
  snowflake.style.pointerEvents = 'none';
  snowflake.style.fontSize = Math.random() * 20 + 'px';
  snowflake.style.left = Math.random() * window.innerWidth + 'px';
  snowflake.style.animation = 'fall ' + (Math.random() * 5 + 5) + 's linear infinite';
  return snowflake;
}

function createSnowfall() {
  const snowfallContainer = document.createElement('div');
  snowfallContainer.style.position = 'fixed';
  snowfallContainer.style.top = '0';
  snowfallContainer.style.left = '0';
  snowfallContainer.style.width = '100%';
  snowfallContainer.style.height = '100%';
  snowfallContainer.style.pointerEvents = 'none';
  snowfallContainer.style.zIndex = '9999';

  for (let i = 0; i < 50; i++) {
    const snowflake = createSnowflake();
    snowfallContainer.appendChild(snowflake);
  }

  document.body.appendChild(snowfallContainer);
}

window.addEventListener('load', createSnowfall);
