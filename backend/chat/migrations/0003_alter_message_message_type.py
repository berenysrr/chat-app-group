from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("chat", "0002_message_client_message_id_and_more"),
    ]

    operations = [
        migrations.AlterField(
            model_name="message",
            name="message_type",
            field=models.CharField(
                choices=[("text", "Text"), ("audio", "Audio")],
                default="text",
                max_length=10,
            ),
        ),
    ]
