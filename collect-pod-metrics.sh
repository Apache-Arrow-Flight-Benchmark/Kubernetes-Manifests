#!/bin/bash
#
# collect-pod-metrics.sh
#
# Periodically capture CPU / memory usage for a single Kubernetes Pod
# and append the results to a log file. If the Pod has a CPU limit,
# the script also records usage as a percentage of that limit.

POD_NAME="ibm-server-57f788d48f-lxsq7"   # target Pod
NAMESPACE="default"                      # target namespace
OUTPUT_FILE="pod-metrics.log"            # where to store samples

# Get the CPU limit for the first container in the Pod (may be empty)
LIMIT_CPU=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" \
              -o=jsonpath="{.spec.containers[0].resources.limits.cpu}")

if [ -z "$LIMIT_CPU" ]; then
    LIMIT_CPU_M="no-limit"
else
    # Convert "500m" → 500 ; "1" → 1000 ; "10" → 10000  (millicores)
    if [[ "$LIMIT_CPU" == *m ]]; then
        LIMIT_CPU_M=$(echo "$LIMIT_CPU" | sed 's/m//')
    else
        LIMIT_CPU_M=$(echo "$LIMIT_CPU * 1000" | bc)
    fi
fi

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    METRICS=$(kubectl top pod "$POD_NAME" -n "$NAMESPACE" --no-headers 2>/dev/null)

    if [ -n "$METRICS" ]; then
        CPU_M=$(echo "$METRICS" | awk '{print $2}' | sed 's/m//')
        MEM=$(echo "$METRICS" | awk '{print $3}')

        if [[ "$LIMIT_CPU_M" != "no-limit" ]]; then
            CPU_PERC=$(echo "scale=4; $CPU_M/$LIMIT_CPU_M*100" | bc)
            CPU_PERC_FMT=$(printf "%.2f" "$CPU_PERC")
            CPU_STRING="CPU_percent_of_limit=${CPU_PERC_FMT}%"
        else
            CPU_STRING="CPU_percent_of_limit=no-limit"
        fi

        echo "$TIMESTAMP $METRICS $CPU_STRING" >> "$OUTPUT_FILE"
    else
        echo "$TIMESTAMP pod not found or metrics not available" >> "$OUTPUT_FILE"
    fi

    sleep 1
done
