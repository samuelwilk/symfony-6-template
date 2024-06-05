<?php

declare(strict_types=1);

namespace App\Tasks;

use GrumPHP\Formatter\ProcessFormatterInterface;
use GrumPHP\Process\ProcessBuilder;
use GrumPHP\Runner\TaskResult;
use GrumPHP\Runner\TaskResultInterface;
use GrumPHP\Task\AbstractExternalTask;
use GrumPHP\Task\Config\ConfigOptionsResolver;
use GrumPHP\Task\Context\ContextInterface;
use GrumPHP\Task\Context\GitPreCommitContext;
use GrumPHP\Task\Context\RunContext;
use Symfony\Component\OptionsResolver\OptionsResolver;

/**
 * @extends AbstractExternalTask<DoctrineSchemaValidateTask>
 */
class DoctrineSchemaValidateTask extends AbstractExternalTask
{
    public function __construct(ProcessBuilder $processBuilder, ProcessFormatterInterface $formatter)
    {
        parent::__construct($processBuilder, $formatter);
    }

    public static function getConfigurableOptions(): ConfigOptionsResolver
    {
        $resolver = new OptionsResolver();
        $resolver->setDefaults([
            'console_path' => 'bin/console',
            'skip_mapping' => false,
            'skip_sync' => false,
            'triggered_by' => ['php', 'xml', 'yml'],
        ]);

        $resolver->addAllowedTypes('skip_mapping', ['bool']);
        $resolver->addAllowedTypes('skip_sync', ['bool']);
        $resolver->addAllowedTypes('triggered_by', ['array']);

        return ConfigOptionsResolver::fromOptionsResolver($resolver);
    }

    public function canRunInContext(ContextInterface $context): bool
    {
        return $context instanceof GitPreCommitContext || $context instanceof RunContext;
    }

    public function run(ContextInterface $context): TaskResultInterface
    {
        $config = $this->getConfig()->getOptions();
        $files = $context->getFiles()->extensions($config['triggered_by']);

        if (0 === \count($files)) {
            return TaskResult::createSkipped($this, $context);
        }

        $arguments = $this->processBuilder->createArgumentsForCommand('php');
        $arguments->add($config['console_path']);
        $arguments->add('doctrine:schema:validate');
        $arguments->addOptionalArgument('--skip-mapping', $config['skip_mapping']);
        $arguments->addOptionalArgument('--skip-sync', $config['skip_sync']);

        $process = $this->processBuilder->buildProcess($arguments);

        $process->run();

        if (!$process->isSuccessful()) {
            return TaskResult::createFailed($this, $context, $this->formatter->format($process));
        }

        return TaskResult::createPassed($this, $context);
    }
}
