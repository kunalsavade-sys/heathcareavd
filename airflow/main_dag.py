from airflow import DAG
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from datetime import datetime, timedelta

# Default arguments
default_args = {
    "owner": "airflow",
    "start_date": datetime(2024, 1, 1),  # Fixed start date
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

# Parent DAG
with DAG(
    dag_id="parent_dag",
    schedule_interval="0 5 * * *",  # Runs daily at 5 AM
    description="Parent DAG to trigger PySpark and BigQuery DAGs",
    default_args=default_args,
    catchup=False,   # VERY IMPORTANT
    tags=["parent", "orchestration", "etl"],
) as dag:

    trigger_pyspark_dag = TriggerDagRunOperator(
        task_id="trigger_pyspark_dag",
        trigger_dag_id="pyspark_dag",
        wait_for_completion=True,
    )

    trigger_bigquery_dag = TriggerDagRunOperator(
        task_id="trigger_bigquery_dag",
        trigger_dag_id="bigquery_dag",
        wait_for_completion=True,
    )

    trigger_pyspark_dag >> trigger_bigquery_dag
