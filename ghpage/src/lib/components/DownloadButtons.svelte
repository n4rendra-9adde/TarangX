<script>
	export let downloads = [
		{ platform: 'android', icon: 'fa-brands fa-android', name: 'Android APK', href: 'https://github.com/n4rendra-9adde/TarangX/releases/latest/download/TarangX-Android.apk' },
		{ platform: 'linux', icon: 'fa-brands fa-linux', name: 'Linux Package', href: 'https://github.com/n4rendra-9adde/TarangX/releases/latest/download/TarangX-Linux.tar.gz' },
		{ platform: 'windows', icon: 'fa-brands fa-windows', name: 'Windows ZIP', href: 'https://github.com/n4rendra-9adde/TarangX/releases/latest/download/TarangX-Windows.zip' }
	];

	const githubReleaseLink = "https://github.com/n4rendra-9adde/TarangX/releases/latest";
</script>

<div class="download-section">
	<!-- Top row of platform direct download buttons -->
	<div class="download-buttons">
		{#each downloads as download}
			<a href={download.href} class="download-btn" target="_blank" rel="noopener noreferrer">
				<i class={download.icon}></i> 
				<span>{download.name}</span>
			</a>
		{/each}
	</div>

	<!-- Larger buttons for Direct APK and GitHub Releases -->
	<div class="custom-download-buttons">
		<a href="https://github.com/n4rendra-9adde/TarangX/releases/latest/download/TarangX-Android.apk" class="custom-btn" target="_blank" rel="noopener noreferrer">
			<i class="fa-brands fa-android"></i>
			<div class="button-info">
				<span>Download APK</span>
				<small>Direct Android Download</small>
			</div>
		</a>
		<a href={githubReleaseLink} class="custom-btn" target="_blank" rel="noopener noreferrer">
			<i class="fa-brands fa-github"></i>
			<div class="button-info">
				<span>GitHub Releases</span>
				<small>All Platforms & Notes</small>
			</div>
		</a>
	</div>
</div>

<style>
	.download-section { 
		/* reduce bottom margin so following section (About) sits closer on mobile */
		margin-bottom: 1rem; 
		/* Add horizontal padding to prevent elements from touching the screen edges */
		padding: 0 1rem;
	}
	
	.download-buttons { 
		display: flex; 
		gap: 1rem; 
		justify-content: center; 
		flex-wrap: wrap;
	}
	
	.download-btn { 
		padding: 0.8rem 1.2rem; 
		background: rgba(255, 255, 255, 0.08); 
		border: 2px solid rgba(255, 255, 255, 0.15); 
		border-radius: 12px; 
		backdrop-filter: blur(12px); 
		display: flex; 
		align-items: center; 
		justify-content: center; 
		gap: 8px; 
		transition: all .3s ease; 
		/* Allow buttons to grow and shrink flexibly from a base size */
		flex: 1 1 120px;
		max-width: 150px; /* Prevent buttons from becoming too wide on larger screens */
		text-decoration: none;
		color: #ffffff;
		font-weight: 500;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}
	
	.download-btn:hover { 
		background: rgba(255, 255, 255, 0.15);
		border-color: rgba(255, 255, 255, 0.3); 
		box-shadow: 0 6px 20px rgba(255, 255, 255, 0.2);
		transform: translateY(-2px) scale(1.02);
	}
	
	.download-btn i { 
		font-size: 1.3rem; 
		color: #ffffff; 
		text-shadow: 0 0 8px rgba(255, 255, 255, 0.4);
	}
	
	.download-btn span { 
		font-size: 0.9rem; 
		font-weight: 600; 
		color: #ffffff; 
		text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.6);
	}

	.custom-download-buttons {
		display: flex;
		gap: 1.5rem;
		justify-content: center;
		margin-top: 2rem;
		flex-wrap: wrap;
		direction: row;
	}

	/* A common, professional style for the custom GitHub and SourceForge buttons */
	.custom-btn {
		display: flex;
		align-items: center;
		justify-content: flex-start;
		gap: 1rem;
		/* Use the same translucent panel styling as other sections to avoid a 'disabled' solid block look */
		background: rgba(16, 11, 33, 0.15);
		border: 1px solid rgba(255,255,255,0.06);
		color: #fff;
		padding: 0.8rem 1.2rem;
		border-radius: 8px;
		box-shadow: 0 6px 20px rgba(0, 0, 0, 0.25);
		text-decoration: none;
		transition: transform 0.3s ease, box-shadow 0.3s ease;
		/* Flexible sizing for different screens */
		flex: 1 1 280px;
		max-width: 260px;
		min-height: 56px; /* slightly smaller min height */
		box-sizing: border-box; /* Ensures padding is included in the total width/height */
	}

	.custom-btn:hover {
		box-shadow: 0 8px 28px rgba(0, 0, 0, 0.45);
		transform: translateY(-4px);
	}

	.custom-btn .fa-github {
		font-size: 1.8rem;
	}

	/* Common class for the text content inside custom buttons */
	.button-info {
		display: flex;
		flex-direction: column;
		text-align: left;
	}

	.button-info span {
		font-size: 1rem;
		font-weight: bold;
	}

	.button-info small {
		font-size: 0.8rem;
		color: #aaa;
	}

	/* --- Responsive Adjustments --- */

	/* For Tablets */
	@media (max-width: 768px) {
		.custom-btn {
			/* Adjust flexible basis for tablets */
			flex-basis: 260px;
		}
	}
	
	/* For Mobile Phones */
	@media (max-width: 640px) {
		.download-section {
			padding: 0 0.5rem; /* Reduce side padding on small screens */
		}

		.download-buttons {
			gap: 0.5rem; /* Make the gap smaller */
		}
		
		.download-btn {
			padding: 0.6rem 1rem;
			flex-basis: 100px; /* Adjust size for mobile */
		}
		
		.download-btn i { font-size: 1.1rem; }
		.download-btn span { font-size: 0.8rem; }

		/* Stack the custom buttons vertically on mobile and reduce their top margin */
		.custom-download-buttons {
			flex-direction: column;
			gap: 0.8rem;
			/* Ensure the container and its children stretch properly */
			align-items: stretch;
			margin-top: 1rem; /* reduce space above download buttons */
		}
		
		.custom-btn {
			width: 100%;
			max-width: none;
			/* When stacked vertically, don't let buttons flex-grow and stretch the height */
			flex: 0 0 auto;
		}
	}
</style>