#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <pthread.h>
#include <mqtt.h>
#include "posix_sockets.h"

void publish_callback(void **unused, struct mqtt_response_publish *published);
void *client_refresher(void *client);
void exit_example(int status, int sockfd, pthread_t *client_daemon);

int main(int argc, char *argv[])
{
    const char *addr;
    const char *port;
    const char *topic;

    addr = "rudder.dev.qntmnet.com";
    port = "1883";
    topic = "rudderdev/switch_logger";

    char *sr_no = argv[1];
    char *data = argv[2];

    int sockfd = open_nb_socket(addr, port);

    if (sockfd == -1)
    {
        perror("Failed to open socket: ");
        exit_example(EXIT_FAILURE, sockfd, NULL);
    }

    /* setup a client */
    struct mqtt_client client;
    uint8_t sendbuf[500000]; /* sendbuf should be large enough to hold multiple
                              whole mqtt messages */
    uint8_t recvbuf[500000]; /* recvbuf should be large enough any whole mqtt
                              message expected to be received */
    mqtt_init(&client, sockfd, sendbuf, sizeof(sendbuf), recvbuf, sizeof(recvbuf),
              publish_callback);
    const char *client_id = NULL;
    uint8_t connect_flags = MQTT_CONNECT_CLEAN_SESSION;
    mqtt_connect(&client, client_id, NULL, NULL, 0, "quantum", "C0r0u0ntum",
                 connect_flags, 400);

    if (client.error != MQTT_OK)
    {
        fprintf(stderr, "error: %s\n", mqtt_error_str(client.error));
        exit_example(EXIT_FAILURE, sockfd, NULL);
    }

    pthread_t client_daemon;
    if (pthread_create(&client_daemon, NULL, client_refresher, &client))
    {
        fprintf(stderr, "Failed to start client daemon.\n");
        exit_example(EXIT_FAILURE, sockfd, NULL);
    }

    char *application_message = argv[1];
    // printf("%s published : \"%s\"", argv[0], application_message);

    mqtt_publish(&client, topic, application_message,
                 strlen(application_message) + 1, MQTT_PUBLISH_QOS_0);

    if (client.error != MQTT_OK)
    {
        fprintf(stderr, "error: %s\n", mqtt_error_str(client.error));
        exit_example(EXIT_FAILURE, sockfd, &client_daemon);
    }

    // printf("\n%s disconnecting from %s\n", argv[0], addr);
    sleep(1);

    exit_example(EXIT_SUCCESS, sockfd, &client_daemon);
}

void exit_example(int status, int sockfd, pthread_t *client_daemon)
{
    if (sockfd != -1)
        close(sockfd);
    if (client_daemon != NULL)
        pthread_cancel(*client_daemon);
    exit(status);
}

void publish_callback(void **unused, struct mqtt_response_publish *published)
{
    printf("Received MQTT message:\n");
    printf("  Topic: %d %p\n", (int)published->topic_name_size, published->topic_name);
    printf("  Payload: %.*s\n", (int)published->application_message_size, (char *)published->application_message);
    printf("  QoS: %d\n", published->qos_level);
    printf("  Message ID: %d\n", published->packet_id);
}

void *client_refresher(void *client)
{
    while (1)
    {
        mqtt_sync((struct mqtt_client *)client);
        usleep(100000U);
    }
    return NULL;
}
