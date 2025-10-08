import mlflow
import os
import sys

def show_experiments():
    """Lists all experiments in MLflow."""
    print("--- MLflow Experiments ---")
    try:
        experiments = mlflow.search_experiments()
        if not experiments:
            print("No experiments found.")
            return

        for exp in experiments:
            print(f"  - Experiment ID: {exp.experiment_id}")
            print(f"    Name: {exp.name}")
            print(f"    Artifact Location: {exp.artifact_location}")
            print(f"    Lifecycle Stage: {exp.lifecycle_stage}")
            print("-" * 20)
    except Exception as e:
        print(f"An error occurred while fetching experiments: {e}")
        print("Please ensure the MLFLOW_TRACKING_URI is correctly set and the server is accessible.")
        sys.exit(1)

def show_registered_models():
    """Lists all registered models in MLflow."""
    print("\n--- MLflow Registered Models ---")
    try:
        models = mlflow.search_registered_models()
        if not models:
            print("No registered models found.")
            return

        for model in models:
            print(f"  - Model Name: {model.name}")
            if model.description:
                print(f"    Description: {model.description}")
            if model.latest_versions:
                print("    Latest Versions:")
                for v in model.latest_versions:
                    print(f"      - Version: {v.version}")
                    print(f"        Stage: {v.current_stage}")
                    print(f"        Run ID: {v.run_id}")
            print("-" * 20)
    except Exception as e:
        print(f"An error occurred while fetching registered models: {e}")
        print("Please ensure the MLFLOW_TRACKING_URI is correctly set and the server is accessible.")
        sys.exit(1)

if __name__ == "__main__":
    print("### Fetching MLflow Experiments and Registered Models ###\n")
    
    # The MLflow client library automatically reads the MLFLOW_TRACKING_URI environment variable.
    # We just need to ensure it's set.
    tracking_uri = os.getenv("MLFLOW_TRACKING_URI")
    if not tracking_uri:
        print("Error: MLFLOW_TRACKING_URI environment variable is not set.")
        sys.exit(1)
    else:
        print(f"Using MLflow Tracking URI: {tracking_uri}\n")
        show_experiments()
        show_registered_models()

    print("\n### Script finished ###")